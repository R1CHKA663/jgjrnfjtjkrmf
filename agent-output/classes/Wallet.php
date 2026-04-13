<?php
/**
 * Wallet — Double-entry balance ledger
 * All balance mutations go through here.
 * Never update balance directly on users table.
 *
 * Casino Backend v2.0
 */

namespace Casino\Classes;

use PDO;
use RuntimeException;
use InvalidArgumentException;

class Wallet
{
    private PDO $db;

    // Transaction type constants
    public const TYPE_DEPOSIT    = 'deposit';
    public const TYPE_WITHDRAWAL = 'withdrawal';
    public const TYPE_BET        = 'bet';
    public const TYPE_WIN        = 'win';
    public const TYPE_BONUS      = 'bonus';
    public const TYPE_CASHBACK   = 'cashback';
    public const TYPE_REFUND     = 'refund';
    public const TYPE_ADMIN      = 'admin_adjustment';

    public function __construct()
    {
        $this->db = Database::getInstance();
    }

    // ─────────────────────────────────────────────────────────
    //  BALANCE READS
    // ─────────────────────────────────────────────────────────

    /**
     * Get real balance (sum of ledger), not the cached column.
     * Use this for critical operations like bets.
     */
    public function getTrueBalance(int $userId): float
    {
        $sql = 'SELECT COALESCE(SUM(amount), 0) FROM wallet_ledger WHERE user_id = :uid AND currency = \'real\'';
        $stmt = $this->db->prepare($sql);
        $stmt->execute([':uid' => $userId]);
        return (float) $stmt->fetchColumn();
    }

    /**
     * Get bonus balance (sum of ledger).
     */
    public function getBonusBalance(int $userId): float
    {
        $sql = 'SELECT COALESCE(SUM(amount), 0) FROM wallet_ledger WHERE user_id = :uid AND currency = \'bonus\'';
        $stmt = $this->db->prepare($sql);
        $stmt->execute([':uid' => $userId]);
        return (float) $stmt->fetchColumn();
    }

    /**
     * Get both balances at once.
     */
    public function getBalances(int $userId): array
    {
        return [
            'real'  => $this->getTrueBalance($userId),
            'bonus' => $this->getBonusBalance($userId),
        ];
    }

    // ─────────────────────────────────────────────────────────
    //  MUTATIONS (all wrapped in transactions)
    // ─────────────────────────────────────────────────────────

    /**
     * Credit real balance (deposit, win, bonus).
     */
    public function credit(
        int    $userId,
        float  $amount,
        string $type,
        string $description = '',
        ?string $referenceId = null
    ): int {
        $this->validateAmount($amount);
        return $this->insertLedger($userId, $amount, 'real', $type, $description, $referenceId);
    }

    /**
     * Debit real balance (bet, withdrawal).
     * Throws if insufficient funds.
     */
    public function debit(
        int    $userId,
        float  $amount,
        string $type,
        string $description = '',
        ?string $referenceId = null
    ): int {
        $this->validateAmount($amount);

        $this->db->beginTransaction();
        try {
            // Lock the user row
            $bal = $this->getLockedBalance($userId, 'real');

            if ($bal < $amount) {
                throw new RuntimeException(
                    "Insufficient balance. Has: {$bal}, needs: {$amount}"
                );
            }

            $id = $this->insertLedger(
                $userId,
                -$amount,    // negative = debit
                'real',
                $type,
                $description,
                $referenceId
            );

            // Sync cache column
            $this->syncCachedBalance($userId, 'real');

            $this->db->commit();
            return $id;
        } catch (\Throwable $e) {
            $this->db->rollBack();
            throw $e;
        }
    }

    /**
     * Credit bonus balance.
     */
    public function creditBonus(
        int    $userId,
        float  $amount,
        string $description = '',
        ?string $referenceId = null
    ): int {
        $this->validateAmount($amount);
        return $this->insertLedger($userId, $amount, 'bonus', self::TYPE_BONUS, $description, $referenceId);
    }

    /**
     * Place a bet: debit real balance, return ledger row ID.
     * Idempotent via unique reference_id.
     */
    public function placeBet(int $userId, float $amount, string $roundId): int
    {
        // Idempotency: if already debited for this round, return existing id
        $existing = $this->findByReference($userId, $roundId, self::TYPE_BET);
        if ($existing) {
            return $existing['id'];
        }

        return $this->debit(
            $userId,
            $amount,
            self::TYPE_BET,
            "Bet on game round {$roundId}",
            $roundId
        );
    }

    /**
     * Settle a win: credit real balance.
     * Idempotent: cannot pay twice for same round.
     */
    public function settleWin(int $userId, float $amount, string $roundId): int
    {
        // Idempotency guard
        $existing = $this->findByReference($userId, $roundId, self::TYPE_WIN);
        if ($existing) {
            return $existing['id'];
        }

        return $this->credit(
            $userId,
            $amount,
            self::TYPE_WIN,
            "Win from game round {$roundId}",
            $roundId
        );
    }

    /**
     * Get transaction history with pagination.
     */
    public function getHistory(int $userId, int $limit = 50, int $offset = 0): array
    {
        $sql = 'SELECT id, currency, amount, type, description, reference_id, created_at
                FROM wallet_ledger
                WHERE user_id = :uid
                ORDER BY id DESC
                LIMIT :lim OFFSET :off';

        $stmt = $this->db->prepare($sql);
        $stmt->bindValue(':uid', $userId, PDO::PARAM_INT);
        $stmt->bindValue(':lim', $limit,  PDO::PARAM_INT);
        $stmt->bindValue(':off', $offset, PDO::PARAM_INT);
        $stmt->execute();

        return $stmt->fetchAll();
    }

    // ─────────────────────────────────────────────────────────
    //  INTERNALS
    // ─────────────────────────────────────────────────────────

    private function insertLedger(
        int    $userId,
        float  $amount,
        string $currency,
        string $type,
        string $description,
        ?string $referenceId
    ): int {
        $sql = 'INSERT INTO wallet_ledger
                    (user_id, currency, amount, type, description, reference_id, created_at)
                VALUES
                    (:uid, :cur, :amt, :type, :desc, :ref, NOW())';

        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            ':uid'  => $userId,
            ':cur'  => $currency,
            ':amt'  => $amount,
            ':type' => $type,
            ':desc' => $description,
            ':ref'  => $referenceId,
        ]);

        $id = (int) $this->db->lastInsertId();

        // Always sync cache after insert
        $this->syncCachedBalance($userId, $currency);

        return $id;
    }

    /**
     * Get balance with a FOR UPDATE lock (prevents race conditions).
     */
    private function getLockedBalance(int $userId, string $currency): float
    {
        $sql = 'SELECT COALESCE(SUM(amount), 0)
                FROM wallet_ledger
                WHERE user_id = :uid AND currency = :cur
                FOR UPDATE';

        $stmt = $this->db->prepare($sql);
        $stmt->execute([':uid' => $userId, ':cur' => $currency]);
        return (float) $stmt->fetchColumn();
    }

    /**
     * Sync the cached balance column on users table.
     */
    private function syncCachedBalance(int $userId, string $currency): void
    {
        $trueBal = $this->getTrueBalance($userId);
        $col     = $currency === 'bonus' ? 'bonus_balance' : 'balance';

        $sql = "UPDATE users SET {$col} = :bal WHERE id = :uid";
        $stmt = $this->db->prepare($sql);
        $stmt->execute([':bal' => $trueBal, ':uid' => $userId]);
    }

    /**
     * Find existing ledger entry by reference_id + type (idempotency).
     */
    private function findByReference(int $userId, string $referenceId, string $type): ?array
    {
        $sql = 'SELECT id FROM wallet_ledger
                WHERE user_id = :uid AND reference_id = :ref AND type = :type
                LIMIT 1';

        $stmt = $this->db->prepare($sql);
        $stmt->execute([':uid' => $userId, ':ref' => $referenceId, ':type' => $type]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    private function validateAmount(float $amount): void
    {
        if ($amount <= 0) {
            throw new InvalidArgumentException("Amount must be positive. Got: {$amount}");
        }
        if ($amount > 1_000_000) {
            throw new InvalidArgumentException("Amount exceeds maximum single transaction limit.");
        }
    }
}
