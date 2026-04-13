-- ================================================
-- CASINO DATABASE SCHEMA
-- MySQL 8.0+ | UTF8MB4
-- ================================================

CREATE DATABASE IF NOT EXISTS casino_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE casino_db;

-- ------------------------------------------------
-- USERS
-- ------------------------------------------------
CREATE TABLE users (
  id            BIGINT UNSIGNED    NOT NULL AUTO_INCREMENT,
  username      VARCHAR(50)        NOT NULL UNIQUE,
  email         VARCHAR(191)       NOT NULL UNIQUE,
  password_hash VARCHAR(255)       NOT NULL,
  first_name    VARCHAR(100)       DEFAULT NULL,
  last_name     VARCHAR(100)       DEFAULT NULL,
  date_of_birth DATE               DEFAULT NULL,
  country       CHAR(2)            DEFAULT NULL,   -- ISO 3166-1 alpha-2
  currency      CHAR(3)            NOT NULL DEFAULT 'USD',
  balance       DECIMAL(18,2)      NOT NULL DEFAULT 0.00,
  bonus_balance DECIMAL(18,2)      NOT NULL DEFAULT 0.00,
  status        ENUM('active','suspended','banned','pending') NOT NULL DEFAULT 'pending',
  role          ENUM('player','vip','agent','admin') NOT NULL DEFAULT 'player',
  email_verified_at DATETIME       DEFAULT NULL,
  kyc_verified  TINYINT(1)         NOT NULL DEFAULT 0,
  last_login_at DATETIME           DEFAULT NULL,
  last_login_ip VARCHAR(45)        DEFAULT NULL,
  created_at    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME           NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_email   (email),
  INDEX idx_username (username),
  INDEX idx_status  (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------
-- EMAIL VERIFICATION TOKENS
-- ------------------------------------------------
CREATE TABLE email_tokens (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id    BIGINT UNSIGNED NOT NULL,
  token      CHAR(64)        NOT NULL UNIQUE,
  type       ENUM('verify','reset_password') NOT NULL DEFAULT 'verify',
  expires_at DATETIME        NOT NULL,
  used_at    DATETIME        DEFAULT NULL,
  created_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_token (token),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------
-- SESSIONS (server-side)
-- ------------------------------------------------
CREATE TABLE sessions (
  id         VARCHAR(128)    NOT NULL,
  user_id    BIGINT UNSIGNED NOT NULL,
  ip_address VARCHAR(45)     DEFAULT NULL,
  user_agent TEXT            DEFAULT NULL,
  payload    TEXT            DEFAULT NULL,
  expires_at DATETIME        NOT NULL,
  created_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_user_id   (user_id),
  INDEX idx_expires_at (expires_at),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------
-- GAMES CATALOGUE
-- ------------------------------------------------
CREATE TABLE games (
  id           BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  slug         VARCHAR(100)     NOT NULL UNIQUE,
  name         VARCHAR(200)     NOT NULL,
  provider     VARCHAR(100)     NOT NULL,
  category     ENUM('slots','table','live','jackpot','sports','crash','poker') NOT NULL DEFAULT 'slots',
  rtp_config   DECIMAL(5,2)     NOT NULL DEFAULT 96.00,  -- target RTP %
  min_bet      DECIMAL(10,2)    NOT NULL DEFAULT 0.10,
  max_bet      DECIMAL(10,2)    NOT NULL DEFAULT 1000.00,
  volatility   ENUM('low','medium','high') NOT NULL DEFAULT 'medium',
  is_active    TINYINT(1)       NOT NULL DEFAULT 1,
  thumbnail    VARCHAR(500)     DEFAULT NULL,
  created_at   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_category (category),
  INDEX idx_provider (provider)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------
-- BETS / ROUNDS
-- ------------------------------------------------
CREATE TABLE bets (
  id           BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  user_id      BIGINT UNSIGNED  NOT NULL,
  game_id      BIGINT UNSIGNED  NOT NULL,
  session_id   VARCHAR(128)     DEFAULT NULL,
  round_id     VARCHAR(64)      NOT NULL UNIQUE,  -- unique per round
  bet_amount   DECIMAL(18,2)    NOT NULL,
  win_amount   DECIMAL(18,2)    NOT NULL DEFAULT 0.00,
  profit       DECIMAL(18,2)    GENERATED ALWAYS AS (win_amount - bet_amount) STORED,
  multiplier   DECIMAL(10,4)    NOT NULL DEFAULT 0.0000,
  currency     CHAR(3)          NOT NULL DEFAULT 'USD',
  status       ENUM('pending','settled','cancelled','refunded') NOT NULL DEFAULT 'pending',
  rng_seed     VARCHAR(128)     DEFAULT NULL,  -- provably fair seed
  rng_result   JSON             DEFAULT NULL,  -- raw RNG output
  created_at   DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  settled_at   DATETIME         DEFAULT NULL,
  PRIMARY KEY (id),
  INDEX idx_user_game  (user_id, game_id),
  INDEX idx_user_id    (user_id),
  INDEX idx_game_id    (game_id),
  INDEX idx_created_at (created_at),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (game_id) REFERENCES games(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------
-- TRANSACTIONS (финансы)
-- ------------------------------------------------
CREATE TABLE transactions (
  id               BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  user_id          BIGINT UNSIGNED  NOT NULL,
  bet_id           BIGINT UNSIGNED  DEFAULT NULL,
  type             ENUM('deposit','withdrawal','bet','win','bonus','refund','adjustment') NOT NULL,
  amount           DECIMAL(18,2)    NOT NULL,
  balance_before   DECIMAL(18,2)    NOT NULL,
  balance_after    DECIMAL(18,2)    NOT NULL,
  currency         CHAR(3)          NOT NULL DEFAULT 'USD',
  reference        VARCHAR(128)     DEFAULT NULL,
  description      VARCHAR(500)     DEFAULT NULL,
  status           ENUM('pending','completed','failed','reversed') NOT NULL DEFAULT 'completed',
  created_at       DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_user_id    (user_id),
  INDEX idx_type       (type),
  INDEX idx_created_at (created_at),
  INDEX idx_reference  (reference),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (bet_id)  REFERENCES bets(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------
-- RTP STATISTICS (per game, per day)
-- ------------------------------------------------
CREATE TABLE rtp_stats (
  id              BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  game_id         BIGINT UNSIGNED  NOT NULL,
  stat_date       DATE             NOT NULL,
  total_bets      BIGINT UNSIGNED  NOT NULL DEFAULT 0,
  total_wagered   DECIMAL(20,2)    NOT NULL DEFAULT 0.00,
  total_won       DECIMAL(20,2)    NOT NULL DEFAULT 0.00,
  rtp_actual      DECIMAL(8,4)     GENERATED ALWAYS AS (
                    IF(total_wagered > 0, (total_won / total_wagered) * 100, 0)
                  ) STORED,
  rtp_configured  DECIMAL(5,2)     NOT NULL DEFAULT 96.00,
  created_at      DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_game_date (game_id, stat_date),
  INDEX idx_stat_date (stat_date),
  FOREIGN KEY (game_id) REFERENCES games(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ------------------------------------------------
-- SEED GAMES DATA
-- ------------------------------------------------
INSERT INTO games (slug, name, provider, category, rtp_config, min_bet, max_bet, volatility) VALUES
  ('book-of-ra',     'Book of Ra',        'Novomatic',  'slots',  95.10, 0.01, 500.00,  'high'),
  ('starburst',      'Starburst',         'NetEnt',     'slots',  96.09, 0.10, 100.00,  'low'),
  ('gates-olympus',  'Gates of Olympus',  'Pragmatic',  'slots',  96.50, 0.20, 2000.00, 'high'),
  ('sweet-bonanza',  'Sweet Bonanza',     'Pragmatic',  'slots',  96.51, 0.20, 2000.00, 'high'),
  ('blackjack-euro', 'European Blackjack','Evolution',  'table',  99.60, 1.00, 5000.00, 'low'),
  ('roulette-euro',  'European Roulette', 'Evolution',  'table',  97.30, 0.10, 10000.00,'low'),
  ('crash-game',     'Crash',             'Spribe',     'crash',  97.00, 0.10, 1000.00, 'high'),
  ('mega-jackpot',   'Mega Jackpot',      'MicroGaming','jackpot',88.00, 0.50, 10.00,   'high');
