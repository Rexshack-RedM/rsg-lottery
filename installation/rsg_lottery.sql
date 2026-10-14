CREATE TABLE IF NOT EXISTS rsg_lottery_config (
   setting VARCHAR(64) PRIMARY KEY,
   value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS rsg_lottery_draws (
   id INT AUTO_INCREMENT PRIMARY KEY,
   draw_date DATE NOT NULL,
   jackpot INT NOT NULL,
   winning_number TEXT,
   drawn_at DATETIME,
   status VARCHAR(32) DEFAULT 'pending',
   winner_citizenid VARCHAR(64),
   winner_name VARCHAR(128),
   UNIQUE KEY draw_date (draw_date)
);

CREATE TABLE IF NOT EXISTS rsg_lottery_tickets (
    id INT AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(64) NOT NULL,
    ticket_number VARCHAR(16) NOT NULL,
    numbers TEXT NOT NULL,
    draw_date DATE NOT NULL,
    purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY idx_citizen_draw (citizenid, draw_date),
    KEY idx_draw (draw_date)
);

CREATE TABLE IF NOT EXISTS rsg_lottery_winners (
    id INT AUTO_INCREMENT PRIMARY KEY,
    draw_date DATE NOT NULL,
    citizenid VARCHAR(64) NOT NULL,
    winner_name VARCHAR(128) NOT NULL,
    prize INT NOT NULL,
    match_count INT NOT NULL,
    win_type VARCHAR(32) NOT NULL DEFAULT 'regular',
    collected TINYINT NOT NULL DEFAULT 0,
    KEY idx_citizen_collected (citizenid, collected)
);

INSERT IGNORE INTO `rsg_lottery_config` (`setting`, `value`) VALUES ('current_jackpot', 100);
