<?php
/**
 * Database Configuration
 * Casino Backend v2.0
 */

return [
    'host'     => $_ENV['DB_HOST']     ?? 'localhost',
    'port'     => (int)($_ENV['DB_PORT'] ?? 3306),
    'dbname'   => $_ENV['DB_NAME']     ?? 'casino_db',
    'username' => $_ENV['DB_USER']     ?? 'casino_user',
    'password' => $_ENV['DB_PASS']     ?? 'your_strong_password',
    'charset'  => 'utf8mb4',
    'options'  => [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES   => false,
        PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci",
    ],
];
