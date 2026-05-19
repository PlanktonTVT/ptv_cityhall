CREATE TABLE IF NOT EXISTS bm_towns (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(64) NOT NULL,
    treasury DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    tax_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    tax_buy_rate DECIMAL(5,2) NOT NULL DEFAULT 5.00,
    tax_sell_rate DECIMAL(5,2) NOT NULL DEFAULT 6.00,
    mayor_charid VARCHAR(64) NULL,
    mayor_name VARCHAR(128) NULL,
    term_started_at INT NULL,
    term_ends_at INT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_bm_towns_name (name)
);

CREATE TABLE IF NOT EXISTS bm_elections (
    id INT NOT NULL AUTO_INCREMENT,
    town_id INT NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    nomination_ends_at INT NOT NULL,
    voting_ends_at INT NOT NULL,
    winner_charid VARCHAR(64) NULL,
    winner_name VARCHAR(128) NULL,
    created_by_charid VARCHAR(64) NULL,
    created_by_name VARCHAR(128) NULL,
    created_at INT NOT NULL,
    closed_at INT NULL,
    PRIMARY KEY (id),
    KEY idx_bm_elections_town_status (town_id, status),
    CONSTRAINT fk_bm_elections_town
        FOREIGN KEY (town_id) REFERENCES bm_towns(id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bm_candidates (
    id INT NOT NULL AUTO_INCREMENT,
    election_id INT NOT NULL,
    charid VARCHAR(64) NOT NULL,
    identifier VARCHAR(80) NULL,
    name VARCHAR(128) NOT NULL,
    manifesto VARCHAR(255) NOT NULL DEFAULT '',
    created_at INT NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_bm_candidate_once (election_id, charid),
    KEY idx_bm_candidates_election (election_id),
    CONSTRAINT fk_bm_candidates_election
        FOREIGN KEY (election_id) REFERENCES bm_elections(id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bm_votes (
    id INT NOT NULL AUTO_INCREMENT,
    election_id INT NOT NULL,
    candidate_id INT NOT NULL,
    voter_charid VARCHAR(64) NOT NULL,
    voter_name VARCHAR(128) NOT NULL,
    created_at INT NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_bm_vote_once (election_id, voter_charid),
    KEY idx_bm_votes_candidate (candidate_id),
    CONSTRAINT fk_bm_votes_election
        FOREIGN KEY (election_id) REFERENCES bm_elections(id)
        ON DELETE CASCADE,
    CONSTRAINT fk_bm_votes_candidate
        FOREIGN KEY (candidate_id) REFERENCES bm_candidates(id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bm_citizens (
    id INT NOT NULL AUTO_INCREMENT,
    town_id INT NOT NULL,
    charid VARCHAR(64) NOT NULL,
    identifier VARCHAR(80) NULL,
    name VARCHAR(128) NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'pending',
    note VARCHAR(255) NOT NULL DEFAULT '',
    created_at INT NOT NULL,
    approved_at INT NULL,
    removed_at INT NULL,
    decided_by_charid VARCHAR(64) NULL,
    decided_by_name VARCHAR(128) NULL,
    updated_at INT NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_bm_citizen_town_char (town_id, charid),
    KEY idx_bm_citizens_town_status (town_id, status),
    CONSTRAINT fk_bm_citizens_town
        FOREIGN KEY (town_id) REFERENCES bm_towns(id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bm_market_listings (
    id INT NOT NULL AUTO_INCREMENT,
    town_id INT NOT NULL,
    seller_charid VARCHAR(64) NOT NULL,
    seller_name VARCHAR(128) NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    item_label VARCHAR(128) NOT NULL,
    amount INT NOT NULL,
    price_each DECIMAL(12,2) NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'active',
    buyer_charid VARCHAR(64) NULL,
    buyer_name VARCHAR(128) NULL,
    created_at INT NOT NULL,
    sold_at INT NULL,
    PRIMARY KEY (id),
    KEY idx_bm_market_town_status (town_id, status),
    KEY idx_bm_market_seller_status (seller_charid, status),
    CONSTRAINT fk_bm_market_town
        FOREIGN KEY (town_id) REFERENCES bm_towns(id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bm_market_stock (
    id INT NOT NULL AUTO_INCREMENT,
    town_id INT NOT NULL,
    category VARCHAR(32) NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    item_label VARCHAR(128) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    buy_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    sell_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    updated_at INT NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_bm_market_stock_town_item (town_id, item_name),
    KEY idx_bm_market_stock_town_category (town_id, category),
    CONSTRAINT fk_bm_market_stock_town
        FOREIGN KEY (town_id) REFERENCES bm_towns(id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bm_market_taxes (
    id INT NOT NULL AUTO_INCREMENT,
    town_id INT NOT NULL,
    category VARCHAR(32) NOT NULL,
    category_label VARCHAR(64) NOT NULL,
    buy_tax_rate DECIMAL(5,2) NOT NULL DEFAULT 5.00,
    sell_tax_rate DECIMAL(5,2) NOT NULL DEFAULT 6.00,
    updated_at INT NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uniq_bm_market_tax_town_category (town_id, category),
    CONSTRAINT fk_bm_market_tax_town
        FOREIGN KEY (town_id) REFERENCES bm_towns(id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS bm_item_returns (
    id INT NOT NULL AUTO_INCREMENT,
    charid VARCHAR(64) NOT NULL,
    name VARCHAR(128) NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    item_label VARCHAR(128) NOT NULL,
    amount INT NOT NULL,
    reason VARCHAR(160) NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'pending',
    created_at INT NOT NULL,
    claimed_at INT NULL,
    PRIMARY KEY (id),
    KEY idx_bm_item_returns_char_status (charid, status)
);

CREATE TABLE IF NOT EXISTS bm_payouts (
    id INT NOT NULL AUTO_INCREMENT,
    charid VARCHAR(64) NOT NULL,
    name VARCHAR(128) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    reason VARCHAR(160) NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'pending',
    created_at INT NOT NULL,
    paid_at INT NULL,
    PRIMARY KEY (id),
    KEY idx_bm_payouts_char_status (charid, status)
);

CREATE TABLE IF NOT EXISTS bm_ledger (
    id INT NOT NULL AUTO_INCREMENT,
    town_id INT NOT NULL,
    entry_type VARCHAR(32) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    actor_charid VARCHAR(64) NULL,
    actor_name VARCHAR(128) NULL,
    note VARCHAR(255) NOT NULL DEFAULT '',
    created_at INT NOT NULL,
    PRIMARY KEY (id),
    KEY idx_bm_ledger_town_created (town_id, created_at),
    CONSTRAINT fk_bm_ledger_town
        FOREIGN KEY (town_id) REFERENCES bm_towns(id)
        ON DELETE CASCADE
);

INSERT INTO bm_towns (name, tax_rate, tax_buy_rate, tax_sell_rate, treasury)
VALUES
    ('Blackwater', 8.00, 8.00, 9.00, 0.00),
    ('Valentine', 8.00, 8.00, 9.00, 0.00),
    ('Rhodes', 8.00, 8.00, 9.00, 0.00),
    ('Saint Denis', 8.00, 8.00, 9.00, 0.00),
    ('Strawberry', 8.00, 8.00, 9.00, 0.00),
    ('Armadillo', 8.00, 8.00, 9.00, 0.00),
    ('Tumbleweed', 8.00, 8.00, 9.00, 0.00),
    ('Annesburg', 8.00, 8.00, 9.00, 0.00),
    ('Van Horn', 8.00, 8.00, 9.00, 0.00)
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO bm_market_taxes (town_id, category, category_label, buy_tax_rate, sell_tax_rate, updated_at)
SELECT id, 'goods', 'Waren', 8.00, 9.00, UNIX_TIMESTAMP()
FROM bm_towns
WHERE name IN ('Blackwater', 'Valentine', 'Rhodes', 'Saint Denis', 'Strawberry', 'Armadillo', 'Tumbleweed', 'Annesburg', 'Van Horn')
ON DUPLICATE KEY UPDATE category_label = VALUES(category_label);

INSERT INTO bm_market_taxes (town_id, category, category_label, buy_tax_rate, sell_tax_rate, updated_at)
SELECT id, 'weapons', 'Waffen', 10.00, 12.00, UNIX_TIMESTAMP()
FROM bm_towns
WHERE name IN ('Blackwater', 'Valentine', 'Rhodes', 'Saint Denis', 'Strawberry', 'Armadillo', 'Tumbleweed', 'Annesburg', 'Van Horn')
ON DUPLICATE KEY UPDATE category_label = VALUES(category_label);
