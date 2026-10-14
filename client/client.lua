lib.locale()

local isOpen = false
local blips = {}
local points = {}

---------------------------------------------------------------------
-- Seller peds (spawned only while a player is nearby)
---------------------------------------------------------------------
local function spawnSeller(point)
    local model = joaat(point.seller.model)
    if not lib.requestModel(model, 10000) then return end

    local c = point.seller.coords
    local ped = CreatePed(model, c.x, c.y, c.z - 1.0, point.seller.heading, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetRandomOutfitVariation(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            label = locale('interact_buy_ticket'),
            icon = 'fas fa-ticket',
            distance = 2.5,
            onSelect = function() OpenLotteryUI() end,
        },
    })
    point.ped = ped
end

local function despawnSeller(point)
    if point.ped and DoesEntityExist(point.ped) then
        exports.ox_target:removeLocalEntity(point.ped)
        DeleteEntity(point.ped)
    end
    point.ped = nil
end

CreateThread(function()
    for _, seller in ipairs(Config.TicketSellers) do
        if Config.Blip and Config.Blip.enabled then
            local blip = BlipAddForCoords(1664425300, seller.coords.x, seller.coords.y, seller.coords.z)
            SetBlipSprite(blip, joaat(Config.Blip.sprite), true)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipName(blip, locale('blip_label'))
            blips[#blips + 1] = blip
        end

        points[#points + 1] = lib.points.new({
            coords = seller.coords,
            distance = Config.SpawnDistance or 60.0,
            seller = seller,
            onEnter = spawnSeller,
            onExit = despawnSeller,
        })
    end
end)

---------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------
local LOCALE_KEYS = {
    jackpot = 'ui_jackpot', ticketPrice = 'ui_ticket_price', pick = 'ui_pick',
    drawIn = 'ui_draw_in', perDraw = 'ui_per_draw', title = 'ui_title', subtitle = 'ui_subtitle',
    tabBuy = 'ui_tab_buy', tabMyTickets = 'ui_tab_my_tickets', tabWinners = 'ui_tab_winners', tabInfo = 'ui_tab_info',
    pickNumbers = 'ui_pick_numbers', selected = 'ui_selected', clear = 'ui_clear', quickPick = 'ui_quick_pick',
    yourTickets = 'ui_your_tickets', noTickets = 'ui_no_tickets',
    pastWinners = 'ui_past_winners', noWinners = 'ui_no_winners',
    howItWorks = 'ui_how_it_works', prizeBreakdown = 'ui_prize_breakdown',
    numbersMatched = 'ui_numbers_matched', prize = 'ui_prize', daily = 'ui_daily',
    close = 'ui_close', drawingNow = 'ui_drawing_now', jackpotLabel = 'ui_jackpot_label',
    unknown = 'ui_unknown', buyTicketBtn = 'ui_buy_ticket_btn', selectNumbers = 'ui_select_numbers',
    noTicketsLeft = 'ui_no_tickets_left', buying = 'ui_buying', left = 'ui_left',
    rowTicketPrice = 'ui_row_ticket_price', rowPickNumbers = 'ui_row_pick_numbers',
    rowNumbersPerTicket = 'ui_row_numbers_per_ticket', rowMaxPerDraw = 'ui_row_max_per_draw',
    rowDrawTime = 'ui_row_draw_time', matched = 'ui_matched',
}

local uiLocale
local function getUiLocale()
    if uiLocale then return uiLocale end
    uiLocale = {}
    for k, v in pairs(LOCALE_KEYS) do uiLocale[k] = locale(v) end
    return uiLocale
end

function OpenLotteryUI()
    if isOpen then return end
    isOpen = true

    local total = lib.callback.await('rsg-lottery:server:collectPrizes', false)
    if total and total > 0 then
        lib.notify({
            title = locale('notify_collected_title'),
            description = locale('notify_collected_desc', total),
            type = 'success',
            duration = 8000,
        })
    end

    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'open', locale = getUiLocale() })
end

local function closeLotteryUI()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

RegisterNUICallback('close', function(_, cb)
    closeLotteryUI()
    cb('ok')
end)

-- Only these server callbacks may be reached from the NUI
local NUI_CALLBACKS = {
    getInfo    = 'rsg-lottery:server:getJackpotInfo',
    getTickets = 'rsg-lottery:server:getMyTickets',
    getWinners = 'rsg-lottery:server:getPastWinners',
}

for name, event in pairs(NUI_CALLBACKS) do
    RegisterNUICallback(name, function(_, cb)
        cb(lib.callback.await(event, false) or {})
    end)
end

RegisterNUICallback('buy', function(data, cb)
    if not isOpen or type(data) ~= 'table' or type(data.numbers) ~= 'table' then return cb(false) end
    cb(lib.callback.await('rsg-lottery:server:buyTicket', false, data.numbers) == true)
end)

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    for _, point in ipairs(points) do
        despawnSeller(point)
        point:remove()
    end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)
