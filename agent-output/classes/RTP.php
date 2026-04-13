<?php
/**
 * RTP (Return to Player) Engine
 * Tracks real-time RTP per game, applies bias correction,
 * and enforces house edge boundaries.
 *
 * Casino Backend v2.0
 */

namespace Casino\Classes;

use PDO;
use RuntimeException;

class RTP
{
    private PDO $db;

    /** House edge per game slug (configurable) */
    private array $houseEdge = [
        'dice'  => 0.01,
        'limbo' => 0.01,
        'mines' => 0.01,
        'plinko'=> 0.01,
        'crash' => 0.01,
    ];

    /** Target RTP = 1 - house_edge */
    private float $defaultHouseEdge = 0.01;

    /**
     * How often (in bets) to re-evaluate RTP drift.
     * Read from env RTP_CHECK_INTERVAL.
     */
    private int $checkInterval;

    /**
     * Strength of correction when RTP drifts.
     * 0.0 = none, 1.0 = full immediate correction.
     */
    private float $correctionStrength;

    public function __construct()
    {
        $this->db               = Database::getInstance();
        $this->checkInterval    = (int) ($_ENV['RTP_CHECK_INTERVAL']    ?? 100);
        $this->correctionStrength = (float) ($_ENV['RTP_CORRECTION_STRENGTH'] ?? 0.3);
    }

    // ─────────────────────────────────────────────────────────
    //  PUBLIC API
    // ─────────────────────────────────────────────────────────

    /**
     * Get the target RTP for a game slug.
     */
    public function getTargetRTP(string $gameSlug): float
    {
        $edge = $this->houseEdge[$gameSlug] ?? $this->defaultHouseEdge;
        return 1.0 - $edge;
    }

    /**
     * Get actual (real) RTP for a game over the last N bets.
     */
    public function getRealRTP(string $gameSlug, int $window = 1000): float
    {
        $sql = 'SELECT
                    SUM(bet_amount)  AS total_wagered,
                    SUM(win_amount)  AS total_paid
                FROM game_rounds
                WHERE game_slug = :slug
                  AND status    = \'settled\'
                ORDER BY id DESC
                LIMIT :window';

        $stmt = $this->db->prepare($sql);
        $stmt->bindValue(':slug',   $gameSlug, PDO::PARAM_STR);
        $stmt->bindValue(':window', $window,   PDO::PARAM_INT);
        $stmt->execute();

        $row = $stmt->fetch();

        if (!$row || (float)$row['total_wagered'] === 0.0) {
            return $this->getTargetRTP($gameSlug);
        }

        return (float)$row['total_paid'] / (float)$row['total_wagered'];
    }

    /**
     * Record a completed game round into the RTP ledger.
     */
    public function recordRound(
        int    $userId,
        string $gameSlug,
        float  $betAmount,
        float  $winAmount,
        string $roundId
    ): void {
        $sql = 'INSERT INTO rtp_logs
                    (user_id, game_slug, bet_amount, win_amount, round_id, created_at)
                VALUES
                    (:user_id, :game_slug, :bet_amount, :win_amount, :round_id, NOW())';

        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            ':user_id'   => $userId,
            ':game_slug' => $gameSlug,
            ':bet_amount'=> $betAmount,
            ':win_amount'=> $winAmount,
            ':round_id'  => $roundId,
        ]);
    }

    /**
     * Compute a bias-corrected win multiplier.
     *
     * When real RTP is above target → slightly reduce wins.
     * When real RTP is below target → slightly increase wins.
     *
     * @param  string $gameSlug
     * @param  float  $rawMultiplier  The fair multiplier before correction
     * @return float  Adjusted multiplier
     */
    public function adjustMultiplier(string $gameSlug, float $rawMultiplier): float
    {
        $realRTP   = $this->getRealRTP($gameSlug);
        $targetRTP = $this->getTargetRTP($gameSlug);
        $drift     = $realRTP - $targetRTP;  // positive = overpaying

        if (abs($drift) < 0.005) {
            return $rawMultiplier;  // within tolerance, no correction
        }

        // Correction factor: reduce/increase multiplier proportionally
        $correctionFactor = 1.0 - ($drift * $this->correctionStrength);
        $correctionFactor = max(0.5, min(1.5, $correctionFactor)); // clamp

        return round($rawMultiplier * $correctionFactor, 8);
    }

    /**
     * Check if we should perform an RTP evaluation this round.
     * Based on total settled round count modulo check interval.
     */
    public function shouldCheckRTP(string $gameSlug): bool
    {
        $sql = 'SELECT COUNT(*) FROM rtp_logs WHERE game_slug = :slug';
        $stmt = $this->db->prepare($sql);
        $stmt->execute([':slug' => $gameSlug]);
        $count = (int) $stmt->fetchColumn();

        return ($count % $this->checkInterval) === 0;
    }

    /**
     * Get RTP stats dashboard for a game.
     */
    public function getStats(string $gameSlug): array
    {
        $sql = 'SELECT
                    COUNT(*)          AS total_rounds,
                    SUM(bet_amount)   AS total_wagered,
                    SUM(win_amount)   AS total_paid,
                    AVG(win_amount / NULLIF(bet_amount, 0)) AS avg_multiplier
                FROM rtp_logs
                WHERE game_slug = :slug';

        $stmt = $this->db->prepare($sql);
        $stmt->execute([':slug' => $gameSlug]);
        $row = $stmt->fetch();

        $totalWagered = (float)($row['total_wagered'] ?? 0);
        $totalPaid    = (float)($row['total_paid']    ?? 0);
        $realRTP      = $totalWagered > 0 ? $totalPaid / $totalWagered : 0;

        return [
            'game_slug'     => $gameSlug,
            'target_rtp'    => $this->getTargetRTP($gameSlug),
            'real_rtp'      => round($realRTP, 6),
            'total_rounds'  => (int)($row['total_rounds'] ?? 0),
            'total_wagered' => $totalWagered,
            'total_paid'    => $totalPaid,
            'house_profit'  => round($totalWagered - $totalPaid, 2),
            'drift'         => round($realRTP - $this->getTargetRTP($gameSlug), 6),
        ];
    }

    /**
     * Generate a provably-fair server seed.
     */
    public static function generateServerSeed(): string
    {
        return bin2hex(random_bytes(32));
    }

    /**
     * Generate a provably-fair client seed.
     */
    public static function generateClientSeed(): string
    {
        return bin2hex(random_bytes(16));
    }

    /**
     * Derive a game outcome from seeds + nonce.
     * Returns a float in [0, 1).
     */
    public static function deriveOutcome(
        string $serverSeed,
        string $clientSeed,
        int    $nonce
    ): float {
        $hmac   = hash_hmac('sha256', "{$clientSeed}:{$nonce}", $serverSeed);
        // Take first 8 hex chars → 32-bit integer
        $intVal = hexdec(substr($hmac, 0, 8));
        return $intVal / 4294967296.0; // 2^32
    }

    /**
     * Verify a past round's fairness.
     * Returns true if the stored outcome matches re-derived outcome.
     */
    public function verifyRound(int $roundId): array
    {
        $sql = 'SELECT * FROM game_rounds WHERE id = :id LIMIT 1';
        $stmt = $this->db->prepare($sql);
        $stmt->execute([':id' => $roundId]);
        $round = $stmt->fetch();

        if (!$round) {
            throw new RuntimeException("Round #{$roundId} not found.");
        }

        $derived  = self::deriveOutcome(
            $round['server_seed'],
            $round['client_seed'],
            (int) $round['nonce']
        );

        $stored   = (float) $round['outcome_float'];
        $matches  = abs($derived - $stored) < 0.000001;

        return [
            'round_id'       => $roundId,
            'game_slug'      => $round['game_slug'],
            'server_seed'    => $round['server_seed'],
            'client_seed'    => $round['client_seed'],
            'nonce'          => $round['nonce'],
            'stored_outcome' => $stored,
            'derived_outcome'=> $derived,
            'is_fair'        => $matches,
        ];
    }
}
