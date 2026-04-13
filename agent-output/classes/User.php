<?php
/**
 * User Model
 * Handles all user-related DB operations
 */

namespace Casino\Classes;

use PDO;
use Casino\Classes\Database;

class User
{
    private PDO $db;

    public function __construct()
    {
        $this->db = Database::getInstance();
    }

    // ────────────────────────────────────────────
    //  CRUD
    // ────────────────────────────────────────────

    /**
     * Create a new user account.
     * Returns the new user ID or throws on duplicate.
     */
    public function create(array $data): int
    {
        $sql = 'INSERT INTO users
                    (username, email, password_hash, first_name, last_name,
                     date_of_birth, country, currency, status)
                VALUES
                    (:username, :email, :password_hash, :first_name, :last_name,
                     :date_of_birth, :country, :currency, :status)';

        $stmt = $this->db->prepare($sql);
        $stmt->execute([
            ':username'      => $data['username'],
            ':email'         => strtolower(trim($data['email'])),
            ':password_hash' => password_hash($data['password'], PASSWORD_BCRYPT, ['cost' => 12]),
            ':first_name'    => $data['first_name']    ?? null,
            ':last_name'     => $data['last_name']     ?? null,
            ':date_of_birth' => $data['date_of_birth'] ?? null,
            ':country'       => strtoupper($data['country'] ?? 'US'),
            ':currency'      => strtoupper($data['currency']  ?? 'USD'),
            ':status'        => 'active',  // set 'pending' if email verification required
        ]);

        return (int)$this->db->lastInsertId();
    }

    /**
     * Find user by ID.
     */
    public function findById(int $id): ?array
    {
        $stmt = $this->db->prepare(
            'SELECT * FROM users WHERE id = :id LIMIT 1'
        );
        $stmt->execute([':id' => $id]);
        $row = $stmt->fetch();
        return $row !== false ? $row : null;
    }

    /**
     * Find user by email.
     */
    public function findByEmail(string $email): ?array
    {
        $stmt = $this->db->prepare(
            'SELECT * FROM users WHERE email = :email LIMIT 1'
        );
        $stmt->execute([':email' => strtolower(trim($email))]);
        $row = $stmt->fetch();
        return $row !== false ? $row : null;
    }

    /**
     * Find user by username.
     */
    public function findByUsername(string $username): ?array
    {
        $stmt = $this->db->prepare(
            'SELECT * FROM users WHERE username = :username LIMIT 1'
        );
        $stmt->execute([':username' => $username]);
        $row = $stmt->fetch();
        return $row !== false ? $row : null;
    }

    /**
     * Verify password.
     */
    public function verifyPassword(array $user, string $password): bool
    {
        return password_verify($password, $user['password_hash']);
    }

    /**
     * Update last login timestamp and IP.
     */
    public function updateLastLogin(int $userId, string $ip): void
    {
        $stmt = $this->db->prepare(
            'UPDATE users SET last_login_at = NOW(), last_login_ip = :ip WHERE id = :id'
        );
        $stmt->execute([':ip' => $ip, ':id' => $userId]);
    }

    /**
     * Get user balance.
     */
    public function getBalance(int $userId): array
    {
        $stmt = $this->db->prepare(
            'SELECT balance, bonus_balance, currency FROM users WHERE id = :id'
        );
        $stmt->execute([':id' => $userId]);
        return $stmt->fetch();
    }

    /**
     * Debit user balance (bet placement). Uses DB transaction externally.
     */
    public function debit(int $userId, float $amount): array
    {
        // Lock the row for atomic update
        $stmt = $this->db->prepare(
            'SELECT balance FROM users WHERE id = :id FOR UPDATE'
        );
        $stmt->execute([':id' => $userId]);
        $row = $stmt->fetch();

        if (!$row || (float)$row['balance'] < $amount) {
            throw new \RuntimeException('Insufficient balance');
        }

        $before = (float)$row['balance'];
        $after  = round($before - $amount, 2);

        $this->db->prepare(
            'UPDATE users SET balance = :after WHERE id = :id'
        )->execute([':after' => $after, ':id' => $userId]);

        return ['before' => $before, 'after' => $after];
    }

    /**
     * Credit user balance (win payout). Uses DB transaction externally.
     */
    public function credit(int $userId, float $amount): array
    {
        $stmt = $this->db->prepare(
            'SELECT balance FROM users WHERE id = :id FOR UPDATE'
        );
        $stmt->execute([':id' => $userId]);
        $row = $stmt->fetch();

        $before = (float)$row['balance'];
        $after  = round($before + $amount, 2);

        $this->db->prepare(
            'UPDATE users SET balance = :after WHERE id = :id'
        )->execute([':after' => $after, ':id' => $userId]);

        return ['before' => $before, 'after' => $after];
    }

    /**
     * Check username and email uniqueness.
     * Returns array of taken fields.
     */
    public function checkUnique(string $username, string $email): array
    {
        $taken = [];

        $stmt = $this->db->prepare('SELECT id FROM users WHERE username = :u LIMIT 1');
        $stmt->execute([':u' => $username]);
        if ($stmt->fetch()) $taken[] = 'username';

        $stmt = $this->db->prepare('SELECT id FROM users WHERE email = :e LIMIT 1');
        $stmt->execute([':e' => strtolower($email)]);
        if ($stmt->fetch()) $taken[] = 'email';

        return $taken;
    }

    /**
     * Safe public profile (no password hash).
     */
    public function safeProfile(array $user): array
    {
        unset($user['password_hash']);
        return $user;
    }
}
