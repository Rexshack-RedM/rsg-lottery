Config = {}

Config.TicketPrice = 10
Config.NumbersPerTicket = 5
Config.NumberMin = 1
Config.NumberMax = 20
Config.MaxTicketsPerDraw = 5
Config.BaseJackpot = 100
Config.PayoutMethod = 'cash' -- cash or bank (how prizes are paid out)

-- matched numbers = prize in $ ('jackpot' = share of the jackpot)
Config.Prizes = {
    [2] = 20,
    [3] = 100,
    [4] = 200,
    [5] = 'jackpot',
}

-- daily draw time in 'minute hour * * *' format (server time)
Config.DrawCron = '0 21 * * *'

Config.TicketSellers = {
    {   -- valentine ticket seller
        model = 'u_m_m_nbxshadydealer_01',
        coords = vector3(-326.36, 795.19, 117.89),
        heading = 191.97,
    },
    {   -- strawberry ticket seller
        model = 'u_m_m_nbxshadydealer_01',
        coords = vector3(-1770.11, -383.33, 157.71),
        heading = 147.81,
    },
    {   -- blackwater ticket seller
        model = 'u_m_m_nbxshadydealer_01',
        coords = vector3(-807.94, -1322.69, 43.66),
        heading = 282.34,
    },
    {   -- armadillo ticket seller
        model = 'u_m_m_nbxshadydealer_01',
        coords = vector3(-3664.35, -2620.06, -13.64),
        heading = 9.06,
    },
    {   -- rhodes ticket seller
        model = 'u_m_m_nbxshadydealer_01',
        coords = vector3(1234.58, -1292.62, 76.96),
        heading = 322.99,
    },
    {   -- st-denis ticket seller
        model = 'u_m_m_nbxshadydealer_01',
        coords = vector3(2733.34, -1395.83, 46.20),
        heading = 31.11,
    },
    {   -- van-horn ticket seller
        model = 'u_m_m_nbxshadydealer_01',
        coords = vector3(2926.42, 1278.16, 44.63),
        heading = 75.40,
    },
    -- Add as many towns/seller peds as you like, e.g.:
    -- {
    --     model = 'a_m_m_saloon_01',
    --     coords = vector3(2726.0, 1374.0, 45.0),
    --     heading = 90.0,
    -- },
}

-- peds spawn when a player is within this distance
Config.SpawnDistance = 60.0

Config.Blip = {
    enabled = true,
    sprite = 'blip_shop_train',
    scale = 0.2,
}

-- Discord webhook settings live in server/sv_config.lua (kept off the client)
