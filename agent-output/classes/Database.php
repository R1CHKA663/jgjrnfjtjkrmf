<?php
/**
 * Database — PDO Singleton
 * Thread-safe, lazy-init connection
 */

namespace Casino\Classes;

use PDO;
use PDOException;
use RuntimeException;

class Database
{
    private static ?PDO $instance = null;
    private static array $config  = [];

    private function __construct() {}
    private function __clone() {}

    /**
     * Get the PDO singleton instance.
     */
    public static function getInstance(): PDO
    {
        if (self::$instance === null) {
            self::$instance = self::connect();
        }
        return self::$instance;
    }

    /**
     * Create a new PDO connection.
     */
    private static function connect(): PDO
    {
        $cfg = self::loadConfig();

        $dsn = sprintf(
            'mysql:host=%s;port=%d;dbname=%s;charset=%s',
            $cfg['host'],
            $cfg['port'],
            $cfg['dbname'],
            $cfg['charset']
        );

        try {
            return new PDO($dsn, $cfg['username'], $cfg['password'], $cfg['options']);
        } catch (PDOException $e) {
            // Never expose credentials in production errors
            throw new RuntimeException('Database connection failed: ' . $e->getMessage());
        }
    }

    /**
     * Load config from config/database.php
     */
    private static function loadConfig(): array
    {
        if (empty(self::$config)) {
            $configPath = __DIR__ . '/../config/database.php';
            if (!file_exists($configPath)) {
                throw new RuntimeException('Database config file not found.');
            }
            self::$config = require $configPath;
        }
        return self::$config;
    }

    /**
     * Begin transaction
     */
    public static function beginTransaction(): void
    {
        self::getInstance()->beginTransaction();
    }

    /**
     * Commit transaction
     */
    public static function commit(): void
    {
        self::getInstance()->commit();
    }

    /**
     * Rollback transaction
     */
    public static function rollback(): void
    {
        if (self::getInstance()->inTransaction()) {
            self::getInstance()->rollBack();
        }
    }
}
