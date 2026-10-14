local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local currentJackpot = Config.BaseJackpot
local busy = {}            -- per-player lock for buy / collect
local drawing = false      -- guards against overlapping draw runs

---------------------------------------------------------------------
-- Draw time helpers (parsed once from Config.DrawCron 'min hour * * *')
---------------------------------------------------------------------
local cronParts = {}
for part in Config.DrawCron:gmatch('%S+') do cronParts[#cronParts + 1] = part end
local DRAW_MIN  = tonumber(cronParts[1]) or 0
local DRAW_HOUR = tonumber(cronParts[2]) or 21

local function todayDrawTime()
    local t = os.date('*t')
    t.hour, t.min, t.sec = DRAW_HOUR, DRAW_MIN, 0
    return os.time(t)
end

-- Draw that newly bought tickets belong to: today until draw time, then tomorrow
local function getOpenDrawDate()
    if os.time() < todayDrawTime() then
        return os.date('%Y-%m-%d')
    end
    return os.date('%Y-%m-%d', os.time() + 86400)
end

local function getNextDrawTimestamp()
    local t = todayDrawTime()
    if os.time() >= t then t = t + 86400 end
    return t
end

---------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------
local function saveJackpot()
    MySQL.update.await(
        'INSERT INTO rsg_lottery_config (setting, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = VALUES(value)',
        { 'current_jackpot', currentJackpot })
end

local function loadJackpot()
    local value = MySQL.scalar.await('SELECT value FROM rsg_lottery_config WHERE setting = ?', { 'current_jackpot' })
    currentJackpot = tonumber(value) or Config.BaseJackpot
    saveJackpot()
end

local function ensureDraw(drawDate)
    MySQL.insert.await('INSERT IGNORE INTO rsg_lottery_draws (draw_date, jackpot, status) VALUES (?, ?, ?)',
        { drawDate, currentJackpot, 'pending' })
end

local function isDrawOpen(drawDate)
    local status = MySQL.scalar.await('SELECT status FROM rsg_lottery_draws WHERE draw_date = ?', { drawDate })
    return status == nil or status == 'pending'
end

local function countTickets(citizenid, drawDate)
    return tonumber(MySQL.scalar.await(
        'SELECT COUNT(*) FROM rsg_lottery_tickets WHERE citizenid = ? AND draw_date = ?',
        { citizenid, drawDate })) or 0
end

---------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------
local TICKET_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
local function randomTicketId(len)
    local out = {}
    for i = 1, len do
        local idx = math.random(1, #TICKET_CHARS)
        out[i] = TICKET_CHARS:sub(idx, idx)
    end
    return table.concat(out)
end

local function generateWinningNumbers()
    local pool = {}
    for i = Config.NumberMin, Config.NumberMax do pool[#pool + 1] = i end
    local selected = {}
    for _ = 1, Config.NumbersPerTicket do
        selected[#selected + 1] = table.remove(pool, math.random(1, #pool))
    end
    table.sort(selected)
    return selected
end

local function countMatches(playerNums, winningSet)
    local count = 0
    for _, v in ipairs(playerNums) do
        if winningSet[v] then count = count + 1 end
    end
    return count
end

local function formatName(charinfo)
    if not charinfo or not charinfo.firstname then return nil end
    return ('%s %s'):format(charinfo.firstname, charinfo.lastname or '')
end

local function getCharacterName(citizenid)
    local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if Player then return formatName(Player.PlayerData.charinfo) or citizenid end
    local charinfo = MySQL.scalar.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
    return (charinfo and formatName(json.decode(charinfo))) or citizenid
end

local function notify(target, title, description, nType, duration)
    TriggerClientEvent('ox_lib:notify', target, {
        title = title, description = description, type = nType, duration = duration or 5000,
    })
end

local JACKPOT_MATCHES = Config.NumbersPerTicket
for match, prize in pairs(Config.Prizes) do
    if prize == 'jackpot' then JACKPOT_MATCHES = match break end
end

---------------------------------------------------------------------
-- Draw processing
---------------------------------------------------------------------
local function settleDraw(drawDate, winningNumbers, jackpot)
    local tickets = MySQL.query.await('SELECT citizenid, numbers FROM rsg_lottery_tickets WHERE draw_date = ?', { drawDate }) or {}

    local winningSet = {}
    for _, v in ipairs(winningNumbers) do winningSet[v] = true end

    local regular, jackpotWinners = {}, {}
    for _, ticket in ipairs(tickets) do
        local nums = json.decode(ticket.numbers) or {}
        local matches = countMatches(nums, winningSet)
        local prize = Config.Prizes[matches]
        if prize == 'jackpot' then
            jackpotWinners[#jackpotWinners + 1] = ticket.citizenid
        elseif type(prize) == 'number' and prize > 0 then
            regular[#regular + 1] = { citizenid = ticket.citizenid, prize = prize, matches = matches }
        end
    end

    for _, w in ipairs(regular) do
        local name = getCharacterName(w.citizenid)
        MySQL.insert.await('INSERT INTO rsg_lottery_winners (draw_date, citizenid, winner_name, prize, match_count, win_type) VALUES (?, ?, ?, ?, ?, ?)',
            { drawDate, w.citizenid, name, w.prize, w.matches, 'regular' })
        local Player = RSGCore.Functions.GetPlayerByCitizenId(w.citizenid)
        if Player then
            notify(Player.PlayerData.source, locale('notify_win_title'), locale('notify_win_unclaimed', w.prize, w.matches), 'success', 10000)
        end
        SendWinWebhook(name, w.prize, w.matches)
    end

    if #jackpotWinners > 0 then
        local split = math.floor(jackpot / #jackpotWinners)
        local names = {}
        for _, citizenid in ipairs(jackpotWinners) do
            local name = getCharacterName(citizenid)
            names[#names + 1] = name
            MySQL.insert.await('INSERT INTO rsg_lottery_winners (draw_date, citizenid, winner_name, prize, match_count, win_type) VALUES (?, ?, ?, ?, ?, ?)',
                { drawDate, citizenid, name, split, JACKPOT_MATCHES, 'jackpot' })
            local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
            if Player then
                notify(Player.PlayerData.source, locale('notify_jackpot_title'), locale('notify_jackpot_unclaimed', split), 'success', 15000)
            end
            SendJackpotWebhook(name, split, Config.BaseJackpot)
        end

        local joined = table.concat(names, ', ')
        notify(-1, locale('notify_jackpot_global_title'), locale('notify_jackpot_global_desc', joined, jackpot), 'inform', 15000)
        MySQL.update.await('UPDATE rsg_lottery_draws SET status = ?, winner_citizenid = ?, winner_name = ? WHERE draw_date = ?',
            { 'claimed', jackpotWinners[1], joined:sub(1, 128), drawDate })

        currentJackpot = Config.BaseJackpot
        saveJackpot()
    else
        -- jackpot already grew with every ticket sold, so it simply rolls over
        MySQL.update.await('UPDATE rsg_lottery_draws SET status = ? WHERE draw_date = ?', { 'drawn', drawDate })
    end
end

local function performDraw(drawDate)
    local winningNumbers = generateWinningNumbers()
    MySQL.update.await('UPDATE rsg_lottery_draws SET winning_number = ?, jackpot = ?, drawn_at = NOW() WHERE draw_date = ?',
        { json.encode(winningNumbers), currentJackpot, drawDate })

    notify(-1, locale('notify_draw_title'), locale('notify_draw_desc', table.concat(winningNumbers, ', ')), 'inform', 15000)

    local totalTickets = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM rsg_lottery_tickets WHERE draw_date = ?', { drawDate })) or 0
    SendDrawWebhook(winningNumbers, totalTickets, totalTickets * Config.TicketPrice, currentJackpot)

    settleDraw(drawDate, winningNumbers, currentJackpot)
end

-- Runs every pending draw that is due (also catches up draws missed while the server was offline)
local function runDueDraws()
    if drawing then return end
    drawing = true
    local today = os.date('%Y-%m-%d')
    local due = MySQL.query.await(
        "SELECT DATE_FORMAT(draw_date, '%Y-%m-%d') AS d FROM rsg_lottery_draws WHERE status = 'pending' AND draw_date <= ? ORDER BY draw_date ASC",
        { today }) or {}
    for _, row in ipairs(due) do
        if row.d < today or os.time() >= todayDrawTime() then
            local ok, err = pcall(performDraw, row.d)
            if not ok then print(('^1[rsg-lottery]^7 Draw %s failed: %s'):format(row.d, err)) end
        end
    end
    ensureDraw(getOpenDrawDate())
    drawing = false
end

---------------------------------------------------------------------
-- Player actions
---------------------------------------------------------------------
local function validateNumbers(numbers)
    if type(numbers) ~= 'table' or #numbers ~= Config.NumbersPerTicket then return nil end
    local seen, clean = {}, {}
    for i = 1, Config.NumbersPerTicket do
        local n = math.tointeger(numbers[i])
        if not n or n < Config.NumberMin or n > Config.NumberMax or seen[n] then return nil end
        seen[n] = true
        clean[i] = n
    end
    table.sort(clean)
    return clean
end

local function purchaseTicket(src, Player, numbers)
    local citizenid = Player.PlayerData.citizenid
    local drawDate = getOpenDrawDate()
    ensureDraw(drawDate)

    if drawing or not isDrawOpen(drawDate) then
        notify(src, locale('notify_error'), locale('notify_draw_completed'), 'error')
        return false
    end

    local count = countTickets(citizenid, drawDate)
    if count >= Config.MaxTicketsPerDraw then
        notify(src, locale('notify_error'), locale('notify_ticket_limit'), 'error')
        return false
    end

    if (Player.Functions.GetMoney('cash') or 0) < Config.TicketPrice
        or not Player.Functions.RemoveMoney('cash', Config.TicketPrice, 'lottery-ticket') then
        notify(src, locale('notify_error'), locale('notify_no_money'), 'error')
        return false
    end

    local ticketId = randomTicketId(8)
    MySQL.insert.await('INSERT INTO rsg_lottery_tickets (citizenid, ticket_number, numbers, draw_date) VALUES (?, ?, ?, ?)',
        { citizenid, ticketId, json.encode(numbers), drawDate })

    currentJackpot = currentJackpot + Config.TicketPrice
    saveJackpot()

    notify(src, locale('notify_ticket_bought'), locale('notify_ticket_bought_desc', ticketId, Config.TicketPrice), 'success')
    SendTicketPurchaseWebhook(Player, numbers, ticketId, count + 1, currentJackpot)
    return true
end

local function collectPrizes(src, Player)
    local citizenid = Player.PlayerData.citizenid
    local rows = MySQL.query.await('SELECT id, prize FROM rsg_lottery_winners WHERE citizenid = ? AND collected = 0', { citizenid })
    if not rows or #rows == 0 then return 0 end

    local total = 0
    for _, row in ipairs(rows) do
        -- only pay rows this call actually flipped, so a prize can never be paid twice
        local changed = MySQL.update.await('UPDATE rsg_lottery_winners SET collected = 1 WHERE id = ? AND collected = 0', { row.id })
        if changed and changed > 0 then total = total + row.prize end
    end

    if total > 0 then
        Player.Functions.AddMoney(Config.PayoutMethod, total, 'lottery-winnings')
    end
    return total
end

-- Runs fn with the player resolved and a per-player lock held
local function withPlayer(src, fallback, fn, ...)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or busy[src] then return fallback end
    busy[src] = true
    local ok, result = pcall(fn, src, Player, ...)
    busy[src] = nil
    if not ok then
        print(('^1[rsg-lottery]^7 %s'):format(result))
        return fallback
    end
    return result
end

---------------------------------------------------------------------
-- Callbacks
---------------------------------------------------------------------
lib.callback.register('rsg-lottery:server:buyTicket', function(src, numbers)
    local clean = validateNumbers(numbers)
    if not clean then return false end
    return withPlayer(src, false, purchaseTicket, clean)
end)

lib.callback.register('rsg-lottery:server:collectPrizes', function(src)
    return withPlayer(src, 0, collectPrizes)
end)

lib.callback.register('rsg-lottery:server:getMyTickets', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return {} end
    local rows = MySQL.query.await(
        'SELECT ticket_number, numbers FROM rsg_lottery_tickets WHERE citizenid = ? AND draw_date = ? ORDER BY id ASC',
        { Player.PlayerData.citizenid, getOpenDrawDate() }) or {}
    local result = {}
    for i, t in ipairs(rows) do
        result[i] = { ticket = t.ticket_number, numbers = json.decode(t.numbers) or {} }
    end
    return result
end)

lib.callback.register('rsg-lottery:server:getJackpotInfo', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    local drawDate = getOpenDrawDate()
    local ticketsLeft = 0
    if Player and not drawing and isDrawOpen(drawDate) then
        ticketsLeft = math.max(0, Config.MaxTicketsPerDraw - countTickets(Player.PlayerData.citizenid, drawDate))
    end

    local prizes = {}
    for match, prize in pairs(Config.Prizes) do
        prizes[#prizes + 1] = { match = match, prize = prize }
    end
    table.sort(prizes, function(a, b) return a.match > b.match end)

    return {
        jackpot = currentJackpot,
        ticketPrice = Config.TicketPrice,
        maxPerDraw = Config.MaxTicketsPerDraw,
        ticketsLeft = ticketsLeft,
        numMin = Config.NumberMin,
        numMax = Config.NumberMax,
        numbersPerTicket = Config.NumbersPerTicket,
        secondsToDraw = getNextDrawTimestamp() - os.time(),
        drawTime = ('%02d:%02d'):format(DRAW_HOUR, DRAW_MIN),
        prizes = prizes,
    }
end)

lib.callback.register('rsg-lottery:server:getPastWinners', function()
    local rows = MySQL.query.await([[
        SELECT w.winner_name, w.prize, w.match_count, w.win_type, d.winning_number,
               DATE_FORMAT(w.draw_date, '%Y-%m-%d') AS draw_date
        FROM rsg_lottery_winners w
        LEFT JOIN rsg_lottery_draws d ON d.draw_date = w.draw_date
        ORDER BY w.id DESC LIMIT 50
    ]]) or {}
    local result = {}
    for i, w in ipairs(rows) do
        result[i] = {
            date = w.draw_date,
            winningNumbers = w.winning_number and json.decode(w.winning_number) or {},
            prize = w.prize,
            winnerName = w.winner_name,
            matchCount = w.match_count,
            winType = w.win_type,
        }
    end
    return result
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
end)

---------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------
lib.cron.new(Config.DrawCron, runDueDraws)

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS rsg_lottery_config (
        setting VARCHAR(64) PRIMARY KEY,
        value TEXT NOT NULL
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS rsg_lottery_draws (
        id INT AUTO_INCREMENT PRIMARY KEY,
        draw_date DATE NOT NULL,
        jackpot INT NOT NULL,
        winning_number TEXT,
        drawn_at DATETIME,
        status VARCHAR(32) DEFAULT 'pending',
        winner_citizenid VARCHAR(64),
        winner_name VARCHAR(128),
        UNIQUE KEY draw_date (draw_date)
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS rsg_lottery_tickets (
        id INT AUTO_INCREMENT PRIMARY KEY,
        citizenid VARCHAR(64) NOT NULL,
        ticket_number VARCHAR(16) NOT NULL,
        numbers TEXT NOT NULL,
        draw_date DATE NOT NULL,
        purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY idx_citizen_draw (citizenid, draw_date),
        KEY idx_draw (draw_date)
    )]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS rsg_lottery_winners (
        id INT AUTO_INCREMENT PRIMARY KEY,
        draw_date DATE NOT NULL,
        citizenid VARCHAR(64) NOT NULL,
        winner_name VARCHAR(128) NOT NULL,
        prize INT NOT NULL,
        match_count INT NOT NULL,
        win_type VARCHAR(32) NOT NULL DEFAULT 'regular',
        collected TINYINT NOT NULL DEFAULT 0,
        KEY idx_citizen_collected (citizenid, collected)
    )]])

    loadJackpot()
    runDueDraws()
    print(('^2[rsg-lottery]^7 Loaded. Current jackpot: ^6$%s^7'):format(currentJackpot))
end)
