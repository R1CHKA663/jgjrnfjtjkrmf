-- ============================================================
-- FULL CASINO DATABASE SCHEMA
-- ============================================================

CREATE DATABASE IF NOT EXISTS casino_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE casino_db;

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    avatar VARCHAR(255) DEFAULT 'default.png',
    balance DECIMAL(18,8) DEFAULT 0.00000000,
    bonus_balance DECIMAL(18,8) DEFAULT 0.00000000,
    total_wagered DECIMAL(18,8) DEFAULT 0.00000000,
    total_won DECIMAL(18,8) DEFAULT 0.00000000,
    total_deposited DECIMAL(18,8) DEFAULT 0.00000000,
    vip_level INT DEFAULT 0 COMMENT '0=Bronze,1=Silver,2=Gold,3=Platinum,4=Diamond',
    vip_points INT DEFAULT 0,
    referral_code VARCHAR(20) UNIQUE NOT NULL,
    referred_by INT UNSIGNED DEFAULT NULL,
    email_verified TINYINT(1) DEFAULT 0,
    email_verify_token VARCHAR(100) DEFAULT NULL,
    two_factor_enabled TINYINT(1) DEFAULT 0,
    two_factor_secret VARCHAR(100) DEFAULT NULL,
    is_banned TINYINT(1) DEFAULT 0,
    ban_reason VARCHAR(255) DEFAULT NULL,
    last_login_at TIMESTAMP NULL,
    last_login_ip VARCHAR(45) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (referred_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_referral_code (referral_code),
    INDEX idx_email (email),
    INDEX idx_username (username)
);

-- ============================================================
-- VIP LEVELS
-- ============================================================
CREATE TABLE vip_levels (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    level INT NOT NULL,
    name VARCHAR(50) NOT NULL,
    min_wagered DECIMAL(18,8) NOT NULL,
    cashback_percent DECIMAL(5,2) NOT NULL,
    bonus_multiplier DECIMAL(5,2) DEFAULT 1.00,
    weekly_bonus DECIMAL(18,8) DEFAULT 0,
    color VARCHAR(20) DEFAULT '#888888',
    icon VARCHAR(50) DEFAULT 'bronze.svg'
);

INSERT INTO vip_levels VALUES
(1, 0, 'Bronze',   0,           1.00, 1.00, 0,       '#cd7f32', 'bronze.svg'),
(2, 1, 'Silver',   500,         2.00, 1.10, 5,       '#c0c0c0', 'silver.svg'),
(3, 2, 'Gold',     2000,        3.50, 1.25, 25,      '#ffd700', 'gold.svg'),
(4, 3, 'Platinum', 10000,       5.00, 1.50, 100,     '#e5e4e2', 'platinum.svg'),
(5, 4, 'Diamond',  50000,       8.00, 2.00, 500,     '#b9f2ff', 'diamond.svg');

-- ============================================================
-- WALLETS / TRANSACTIONS
-- ============================================================
CREATE TABLE transactions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    type ENUM('deposit','withdrawal','bet','win','bonus','cashback','referral_commission','refund') NOT NULL,
    amount DECIMAL(18,8) NOT NULL,
    balance_before DECIMAL(18,8) NOT NULL,
    balance_after DECIMAL(18,8) NOT NULL,
    currency VARCHAR(10) DEFAULT 'USD',
    game_id INT UNSIGNED DEFAULT NULL,
    reference_id VARCHAR(100) DEFAULT NULL,
    description VARCHAR(255) DEFAULT NULL,
    status ENUM('pending','completed','failed','cancelled') DEFAULT 'completed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_type (type),
    INDEX idx_created_at (created_at)
);

-- ============================================================
-- DEPOSITS
-- ============================================================
CREATE TABLE deposits (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    method VARCHAR(50) NOT NULL COMMENT 'crypto_btc, crypto_eth, card, etc',
    amount DECIMAL(18,8) NOT NULL,
    currency VARCHAR(10) DEFAULT 'USD',
    crypto_address VARCHAR(255) DEFAULT NULL,
    crypto_txid VARCHAR(255) DEFAULT NULL,
    status ENUM('pending','confirming','completed','failed') DEFAULT 'pending',
    bonus_applied TINYINT(1) DEFAULT 0,
    bonus_amount DECIMAL(18,8) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status)
);

-- ============================================================
-- WITHDRAWALS
-- ============================================================
CREATE TABLE withdrawals (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    method VARCHAR(50) NOT NULL,
    amount DECIMAL(18,8) NOT NULL,
    fee DECIMAL(18,8) DEFAULT 0,
    net_amount DECIMAL(18,8) NOT NULL,
    currency VARCHAR(10) DEFAULT 'USD',
    destination VARCHAR(255) NOT NULL,
    status ENUM('pending','processing','completed','rejected') DEFAULT 'pending',
    admin_note VARCHAR(255) DEFAULT NULL,
    processed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status)
);

-- ============================================================
-- GAMES
-- ============================================================
CREATE TABLE games (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    slug VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    category ENUM('slots','table','crash','dice','instant') NOT NULL,
    rtp DECIMAL(5,2) DEFAULT 97.00,
    min_bet DECIMAL(18,8) DEFAULT 0.10000000,
    max_bet DECIMAL(18,8) DEFAULT 1000.00000000,
    is_active TINYINT(1) DEFAULT 1,
    thumbnail VARCHAR(255) DEFAULT NULL,
    description TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO games (slug, name, category, rtp, min_bet, max_bet) VALUES
('slots-classic',  'Classic Slots',   'slots',   96.00, 0.10, 500.00),
('slots-mega',     'Mega Slots',      'slots',   95.50, 0.10, 1000.00),
('crash',          'Crash',           'crash',   97.00, 0.10, 5000.00),
('dice',           'Dice',            'dice',    99.00, 0.10, 10000.00),
('mines',          'Mines',           'instant', 97.00, 0.10, 1000.00),
('plinko',         'Plinko',          'instant', 97.00, 0.10, 500.00),
('limbo',          'Limbo',           'instant', 99.00, 0.10, 10000.00),
('blackjack',      'Blackjack',       'table',   99.50, 1.00, 5000.00),
('roulette',       'Roulette',        'table',   97.30, 0.10, 5000.00),
('keno',           'Keno',            'instant', 95.00, 0.10, 200.00);

-- ============================================================
-- GAME ROUNDS (all bets/results)
-- ============================================================
CREATE TABLE game_rounds (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    game_id INT UNSIGNED NOT NULL,
    session_seed VARCHAR(64) NOT NULL,
    client_seed VARCHAR(64) NOT NULL,
    nonce BIGINT UNSIGNED DEFAULT 0,
    bet_amount DECIMAL(18,8) NOT NULL,
    win_amount DECIMAL(18,8) DEFAULT 0,
    profit DECIMAL(18,8) DEFAULT 0,
    multiplier DECIMAL(10,4) DEFAULT 0,
    outcome JSON DEFAULT NULL COMMENT 'Game-specific result data',
    is_bonus_bet TINYINT(1) DEFAULT 0,
    rtp_actual DECIMAL(10,4) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (game_id) REFERENCES games(id),
    INDEX idx_user_id (user_id),
    INDEX idx_game_id (game_id),
    INDEX idx_created_at (created_at)
);

-- ============================================================
-- PROVABLY FAIR SEEDS
-- ============================================================
CREATE TABLE provably_fair_seeds (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    server_seed VARCHAR(128) NOT NULL,
    server_seed_hash VARCHAR(128) NOT NULL,
    client_seed VARCHAR(64) NOT NULL,
    nonce BIGINT UNSIGNED DEFAULT 0,
    is_revealed TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_user_id (user_id)
);

-- ============================================================
-- REFERRAL SYSTEM
-- ============================================================
CREATE TABLE referrals (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    referrer_id INT UNSIGNED NOT NULL,
    referred_id INT UNSIGNED NOT NULL,
    level INT DEFAULT 1 COMMENT '1=direct, 2=tier2',
    status ENUM('pending','active','rewarded') DEFAULT 'pending',
    total_commission DECIMAL(18,8) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (referrer_id) REFERENCES users(id),
    FOREIGN KEY (referred_id) REFERENCES users(id),
    UNIQUE KEY unique_referral (referrer_id, referred_id),
    INDEX idx_referrer_id (referrer_id)
);

CREATE TABLE referral_commissions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    referrer_id INT UNSIGNED NOT NULL,
    referred_id INT UNSIGNED NOT NULL,
    game_round_id BIGINT UNSIGNED NOT NULL,
    level INT DEFAULT 1,
    commission_percent DECIMAL(5,2) NOT NULL,
    wagered_amount DECIMAL(18,8) NOT NULL,
    commission_amount DECIMAL(18,8) NOT NULL,
    paid TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (referrer_id) REFERENCES users(id),
    FOREIGN KEY (referred_id) REFERENCES users(id),
    INDEX idx_referrer_id (referrer_id),
    INDEX idx_paid (paid)
);

-- ============================================================
-- BONUS SYSTEM
-- ============================================================
CREATE TABLE bonuses (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    type ENUM('welcome','deposit','free_spin','no_deposit','referral','vip','promo') NOT NULL,
    value_type ENUM('percent','fixed') DEFAULT 'percent',
    value DECIMAL(10,2) NOT NULL,
    max_bonus DECIMAL(18,8) DEFAULT NULL,
    min_deposit DECIMAL(18,8) DEFAULT 0,
    wagering_requirement DECIMAL(5,2) DEFAULT 30.00,
    max_cashout DECIMAL(18,8) DEFAULT NULL,
    free_spins INT DEFAULT 0,
    valid_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_until TIMESTAMP NULL,
    usage_limit INT DEFAULT NULL COMMENT 'NULL = unlimited',
    usage_count INT DEFAULT 0,
    per_user_limit INT DEFAULT 1,
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO bonuses (code, name, type, value_type, value, max_bonus, min_deposit, wagering_requirement, free_spins) VALUES
('WELCOME100', 'Welcome Bonus 100%', 'welcome', 'percent', 100.00, 500.00, 10.00, 30.00, 50),
('RELOAD50',   'Reload Bonus 50%',   'deposit', 'percent', 50.00,  200.00, 20.00, 25.00, 0),
('FREE10',     'No Deposit $10',     'no_deposit','fixed', 10.00,  NULL,   0.00,  40.00, 0),
('VIP200',     'VIP 200% Bonus',     'vip',    'percent', 200.00, 2000.00, 50.00, 20.00, 100);

CREATE TABLE user_bonuses (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    bonus_id INT UNSIGNED NOT NULL,
    amount DECIMAL(18,8) NOT NULL,
    wagering_required DECIMAL(18,8) NOT NULL,
    wagering_completed DECIMAL(18,8) DEFAULT 0,
    free_spins_remaining INT DEFAULT 0,
    status ENUM('active','completed','expired','cancelled','forfeited') DEFAULT 'active',
    expires_at TIMESTAMP NULL,
    completed_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (bonus_id) REFERENCES bonuses(id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status)
);

-- ============================================================
-- CASHBACK SYSTEM
-- ============================================================
CREATE TABLE cashback_records (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    period_start TIMESTAMP NOT NULL,
    period_end TIMESTAMP NOT NULL,
    total_wagered DECIMAL(18,8) NOT NULL,
    total_lost DECIMAL(18,8) NOT NULL,
    cashback_percent DECIMAL(5,2) NOT NULL,
    cashback_amount DECIMAL(18,8) NOT NULL,
    status ENUM('pending','credited','expired') DEFAULT 'pending',
    credited_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_user_id (user_id),
    INDEX idx_period (period_start, period_end)
);

-- ============================================================
-- LEADERBOARD / COMPETITIONS
-- ============================================================
CREATE TABLE leaderboard_entries (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    competition_type ENUM('daily','weekly','monthly','all_time') NOT NULL,
    period_date DATE NOT NULL,
    total_wagered DECIMAL(18,8) DEFAULT 0,
    total_profit DECIMAL(18,8) DEFAULT 0,
    biggest_win DECIMAL(18,8) DEFAULT 0,
    games_played INT DEFAULT 0,
    rank_position INT DEFAULT NULL,
    prize_awarded DECIMAL(18,8) DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE KEY unique_entry (user_id, competition_type, period_date),
    INDEX idx_competition (competition_type, period_date)
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE notifications (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    icon VARCHAR(50) DEFAULT 'bell',
    link VARCHAR(255) DEFAULT NULL,
    is_read TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id),
    INDEX idx_is_read (is_read)
);

-- ============================================================
-- ADMIN / SETTINGS
-- ============================================================
CREATE TABLE settings (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    `key` VARCHAR(100) UNIQUE NOT NULL,
    `value` TEXT NOT NULL,
    type ENUM('string','int','float','bool','json') DEFAULT 'string',
    description VARCHAR(255) DEFAULT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO settings (`key`, `value`, `type`, `description`) VALUES
('site_name',            'CryptoLuck Casino',  'string', 'Site name'),
('maintenance_mode',     '0',                  'bool',   'Maintenance mode on/off'),
('min_withdrawal',       '10.00',              'float',  'Minimum withdrawal amount'),
('max_withdrawal_daily', '5000.00',            'float',  'Max daily withdrawal'),
('referral_commission_l1','5.00',              'float',  'Level 1 referral commission %'),
('referral_commission_l2','2.00',              'float',  'Level 2 referral commission %'),
('cashback_period_days', '7',                  'int',    'Cashback period in days'),
('default_rtp',          '97.00',              'float',  'Default game RTP'),
('house_edge',           '3.00',               'float',  'House edge %'),
('vip_points_per_dollar','1',                  'int',    'VIP points per dollar wagered'),
('welcome_bonus_active', '1',                  'bool',   'Welcome bonus on/off'),
('live_chat_enabled',    '1',                  'bool',   'Live chat widget');

CREATE TABLE admin_users (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('superadmin','admin','moderator','support') DEFAULT 'support',
    permissions JSON DEFAULT NULL,
    last_login_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- CHAT (Live)
-- ============================================================
CREATE TABLE chat_messages (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    room VARCHAR(50) DEFAULT 'general',
    message TEXT NOT NULL,
    is_deleted TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    INDEX idx_room (room),
    INDEX idx_created_at (created_at)
);

-- ============================================================
-- CRASH GAME HISTORY
-- ============================================================
CREATE TABLE crash_rounds (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    hash VARCHAR(128) NOT NULL,
    crash_point DECIMAL(10,4) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL
);

CREATE TABLE crash_bets (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    round_id BIGINT UNSIGNED NOT NULL,
    user_id INT UNSIGNED NOT NULL,
    bet_amount DECIMAL(18,8) NOT NULL,
    cashout_at DECIMAL(10,4) DEFAULT NULL COMMENT 'NULL = did not cash out',
    win_amount DECIMAL(18,8) DEFAULT 0,
    auto_cashout DECIMAL(10,4) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (round_id) REFERENCES crash_rounds(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);
