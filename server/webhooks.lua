local function sendWebhook(embed)
    local cfg = ServerConfig.Webhook
    if not cfg or not cfg.enabled or not cfg.url or cfg.url == '' then return end
    PerformHttpRequest(cfg.url, function() end, 'POST', json.encode({
        username = cfg.title,
        embeds = {{
            title = embed.title,
            description = embed.description,
            color = cfg.color,
            fields = embed.fields or {},
            footer = { text = cfg.footer, icon_url = cfg.footerIcon ~= '' and cfg.footerIcon or nil },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }},
    }), { ['Content-Type'] = 'application/json' })
end

local function field(name, value)
    return { name = name, value = tostring(value), inline = true }
end

function SendTicketPurchaseWebhook(Player, numbers, ticketId, ticketCount, jackpot)
    local ci = Player.PlayerData.charinfo or {}
    sendWebhook({
        title = locale('webhook_ticket_purchased'),
        description = locale('webhook_ticket_purchased_desc', ('%s %s'):format(ci.firstname or '?', ci.lastname or '')),
        fields = {
            field(locale('webhook_field_ticket'), ticketId),
            field(locale('webhook_field_numbers'), table.concat(numbers, ', ')),
            field(locale('webhook_field_cost'), '$' .. Config.TicketPrice),
            field(locale('webhook_field_tickets_today'), ticketCount),
            field(locale('webhook_field_total_spent'), '$' .. ticketCount * Config.TicketPrice),
            field(locale('webhook_field_current_jackpot'), '$' .. jackpot),
        },
    })
end

function SendDrawWebhook(winningNumbers, totalTickets, totalRevenue, jackpot)
    sendWebhook({
        title = locale('webhook_draw_completed'),
        description = locale('webhook_draw_desc', table.concat(winningNumbers, ', ')),
        fields = {
            field(locale('webhook_field_tickets_sold'), totalTickets),
            field(locale('webhook_field_total_revenue'), '$' .. totalRevenue),
            field(locale('webhook_field_jackpot'), '$' .. jackpot),
        },
    })
end

function SendWinWebhook(name, prize, matchCount)
    sendWebhook({
        title = locale('webhook_winner'),
        description = locale('webhook_winner_desc', name, prize),
        fields = {
            field(locale('webhook_field_matching_numbers'), matchCount),
            field(locale('webhook_field_prize'), '$' .. prize),
        },
    })
end

function SendJackpotWebhook(name, prize, jackpotAfter)
    sendWebhook({
        title = locale('webhook_jackpot_title'),
        description = locale('webhook_jackpot_desc', name, prize),
        fields = {
            field(locale('webhook_field_prize'), '$' .. prize),
            field(locale('webhook_field_jackpot_reset'), '$' .. jackpotAfter),
        },
    })
end
