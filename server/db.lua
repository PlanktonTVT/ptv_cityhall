BMDB = {}

local function townDefaults()
    return Config.Town or {}
end

function BMDB.defaultTownKey()
    return tostring(Config.DefaultTown or 'blackwater')
end

function BMDB.isTownKey(townKey)
    townKey = tostring(townKey or '')
    local towns = Config.Towns or {}
    if towns[townKey] then
        return true
    end

    return next(towns) == nil and townKey == BMDB.defaultTownKey()
end

function BMDB.townConfig(townKey)
    local towns = Config.Towns or {}
    townKey = tostring(townKey or BMDB.defaultTownKey())

    if towns[townKey] then
        return townKey, towns[townKey]
    end

    local fallbackKey = BMDB.defaultTownKey()
    if towns[fallbackKey] then
        return fallbackKey, towns[fallbackKey]
    end

    return fallbackKey, townDefaults()
end

function BMDB.townName(townKey)
    local key, town = BMDB.townConfig(townKey)
    return town.Name or town.name or key
end

function BMDB.townKeys()
    local towns = Config.Towns or {}
    local order = {}
    local seen = {}

    local function add(key)
        key = tostring(key or '')
        if key ~= '' and towns[key] and not seen[key] then
            seen[key] = true
            order[#order + 1] = key
        end
    end

    for _, key in ipairs(Config.TownOrder or {}) do
        add(key)
    end

    for key in pairs(towns) do
        add(key)
    end

    if #order == 0 then
        order[1] = BMDB.defaultTownKey()
    end

    return order
end

local migrations = {
    [[
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
        )
    ]],
    [[
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
        )
    ]],
    [[
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
        )
    ]],
    [[
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
        )
    ]],
    [[
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
            KEY idx_bm_citizens_char_created (charid, created_at),
            CONSTRAINT fk_bm_citizens_town
                FOREIGN KEY (town_id) REFERENCES bm_towns(id)
                ON DELETE CASCADE
        )
    ]],
    [[
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
        )
    ]],
    [[
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
            buy_tax_rate DECIMAL(5,2) NOT NULL DEFAULT 5.00,
            sell_tax_rate DECIMAL(5,2) NOT NULL DEFAULT 6.00,
            updated_at INT NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uniq_bm_market_stock_town_item (town_id, item_name),
            KEY idx_bm_market_stock_town_category (town_id, category),
            CONSTRAINT fk_bm_market_stock_town
                FOREIGN KEY (town_id) REFERENCES bm_towns(id)
                ON DELETE CASCADE
        )
    ]],
    [[
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
        )
    ]],
    [[
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
        )
    ]],
    [[
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
        )
    ]],
    [[
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
        )
    ]]
}

function BMDB.bootstrap()
    if not Config.AutoSetupDatabase then
        return
    end

    for _, sql in ipairs(migrations) do
        MySQL.query.await(sql)
    end

    BMDB.ensureTownTaxColumns()
    BMDB.ensureMarketStockColumns()
    BMDB.ensureCitizenIndexes()
end

function BMDB.ensureTownTaxColumns()
    local buyRows = MySQL.query.await("SHOW COLUMNS FROM bm_towns LIKE 'tax_buy_rate'") or {}
    if not buyRows[1] then
        MySQL.query.await('ALTER TABLE bm_towns ADD COLUMN tax_buy_rate DECIMAL(5,2) NOT NULL DEFAULT 5.00 AFTER tax_rate')
        MySQL.update.await(
            'UPDATE bm_towns SET tax_buy_rate = CASE WHEN tax_rate >= ? THEN tax_rate ELSE ? END',
            { Config.Town.MinTaxRate, Config.Town.DefaultBuyTaxRate }
        )
    end

    local sellRows = MySQL.query.await("SHOW COLUMNS FROM bm_towns LIKE 'tax_sell_rate'") or {}
    if not sellRows[1] then
        MySQL.query.await('ALTER TABLE bm_towns ADD COLUMN tax_sell_rate DECIMAL(5,2) NOT NULL DEFAULT 6.00 AFTER tax_buy_rate')
        MySQL.update.await(
            'UPDATE bm_towns SET tax_sell_rate = CASE WHEN tax_buy_rate + ? <= ? THEN tax_buy_rate + ? ELSE ? END',
            { Config.Town.MinSellTaxSpread, Config.Town.MaxTaxRate, Config.Town.MinSellTaxSpread, Config.Town.DefaultSellTaxRate }
        )
    end
end

function BMDB.ensureMarketStockColumns()
    local enabledRows = MySQL.query.await("SHOW COLUMNS FROM bm_market_stock LIKE 'enabled'") or {}
    if not enabledRows[1] then
        MySQL.query.await('ALTER TABLE bm_market_stock ADD COLUMN enabled TINYINT(1) NOT NULL DEFAULT 1 AFTER stock')
        MySQL.update.await('UPDATE bm_market_stock SET enabled = 1 WHERE enabled IS NULL')
    end

    local buyTaxRows = MySQL.query.await("SHOW COLUMNS FROM bm_market_stock LIKE 'buy_tax_rate'") or {}
    local sellTaxRows = MySQL.query.await("SHOW COLUMNS FROM bm_market_stock LIKE 'sell_tax_rate'") or {}
    local addedTaxColumn = false
    if not buyTaxRows[1] then
        MySQL.query.await('ALTER TABLE bm_market_stock ADD COLUMN buy_tax_rate DECIMAL(5,2) NULL AFTER sell_price')
        addedTaxColumn = true
    end
    if not sellTaxRows[1] then
        MySQL.query.await('ALTER TABLE bm_market_stock ADD COLUMN sell_tax_rate DECIMAL(5,2) NULL AFTER buy_tax_rate')
        addedTaxColumn = true
    end

    if addedTaxColumn then
        MySQL.update.await(
            [[
                UPDATE bm_market_stock s
                LEFT JOIN bm_market_taxes t
                    ON t.town_id = s.town_id
                    AND t.category = s.category
                SET
                    s.buy_tax_rate = COALESCE(t.buy_tax_rate, s.buy_tax_rate, 5.00),
                    s.sell_tax_rate = COALESCE(t.sell_tax_rate, s.sell_tax_rate, 6.00)
            ]],
            {}
        )
        MySQL.query.await('ALTER TABLE bm_market_stock MODIFY buy_tax_rate DECIMAL(5,2) NOT NULL DEFAULT 5.00')
        MySQL.query.await('ALTER TABLE bm_market_stock MODIFY sell_tax_rate DECIMAL(5,2) NOT NULL DEFAULT 6.00')
    end
end

function BMDB.ensureCitizenIndexes()
    local rows = MySQL.query.await("SHOW INDEX FROM bm_citizens WHERE Key_name = 'idx_bm_citizens_char_created'") or {}
    if not rows[1] then
        MySQL.query.await('ALTER TABLE bm_citizens ADD KEY idx_bm_citizens_char_created (charid, created_at)')
    end
end

function BMDB.ensureTown()
    local townKey = BMDB.defaultTownKey()
    return BMDB.ensureTownByKey(townKey)
end

function BMDB.ensureTownByKey(townKey)
    local key, town = BMDB.townConfig(townKey)
    local defaults = townDefaults()
    local name = town.Name or town.name or key

    MySQL.insert.await(
        'INSERT INTO bm_towns (name, tax_rate, tax_buy_rate, tax_sell_rate, treasury) VALUES (?, ?, ?, ?, 0.00) ON DUPLICATE KEY UPDATE name = VALUES(name)',
        { name, defaults.DefaultTaxRate, defaults.DefaultBuyTaxRate, defaults.DefaultSellTaxRate }
    )

    return BMDB.getTown(key)
end

function BMDB.ensureAllTowns()
    for _, townKey in ipairs(BMDB.townKeys()) do
        BMDB.ensureTownByKey(townKey)
    end
end

function BMDB.getTown(townKey)
    local key, town = BMDB.townConfig(townKey)
    local name = town.Name or town.name or key
    local rows = MySQL.query.await('SELECT * FROM bm_towns WHERE name = ? LIMIT 1', { name })
    local row = rows and rows[1] or nil
    if row then
        row.key = key
    end

    return row
end

function BMDB.activeElection(townId)
    local rows = MySQL.query.await(
        'SELECT * FROM bm_elections WHERE town_id = ? AND status = ? ORDER BY id DESC LIMIT 1',
        { townId, 'active' }
    )

    return rows and rows[1] or nil
end

function BMDB.citizenship(townId, charid)
    local rows = MySQL.query.await(
        'SELECT * FROM bm_citizens WHERE town_id = ? AND charid = ? LIMIT 1',
        { townId, tostring(charid) }
    )

    return rows and rows[1] or nil
end

function BMDB.latestCitizenshipByChar(charid)
    local rows = MySQL.query.await(
        [[
            SELECT c.*, t.name AS town_name
            FROM bm_citizens c
            LEFT JOIN bm_towns t ON t.id = c.town_id
            WHERE c.charid = ?
            ORDER BY c.created_at DESC, c.updated_at DESC, c.id DESC
            LIMIT 1
        ]],
        { tostring(charid) }
    )

    return rows and rows[1] or nil
end

function BMDB.citizenCounts(townId)
    local rows = MySQL.query.await(
        [[
            SELECT
                COALESCE(SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END), 0) AS pending,
                COALESCE(SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END), 0) AS active
            FROM bm_citizens
            WHERE town_id = ?
        ]],
        { townId }
    )
    local row = rows and rows[1] or {}

    return {
        pending = tonumber(row.pending) or 0,
        active = tonumber(row.active) or 0
    }
end

function BMDB.pendingPayoutTotal(charid)
    local rows = MySQL.query.await(
        'SELECT COALESCE(SUM(amount), 0) AS amount FROM bm_payouts WHERE charid = ? AND status = ?',
        { tostring(charid), 'pending' }
    )

    return tonumber(rows and rows[1] and rows[1].amount) or 0.0
end

function BMDB.pendingItemReturnCount(charid)
    local rows = MySQL.query.await(
        'SELECT COALESCE(SUM(amount), 0) AS amount FROM bm_item_returns WHERE charid = ? AND status = ?',
        { tostring(charid), 'pending' }
    )

    return tonumber(rows and rows[1] and rows[1].amount) or 0
end
