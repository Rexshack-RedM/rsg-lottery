# rsg-lottery

A daily lottery for the RSG Framework (RedM). Players buy tickets from seller NPCs in every major town, pick their numbers, and a draw runs automatically every day. Prizes are held until the winner next visits a ticket seller, and the jackpot grows with every ticket sold until someone wins it.

## Features

- **Daily automatic draw** at a configurable time. Draws missed while the server was offline run as soon as it starts again.
- **Number picker UI** with Quick Pick and Clear buttons, a live jackpot and a countdown to the next draw
- **Prize tiers**: a fixed cash prize for each number of matches, plus a jackpot shared between all top winners
- **Rolling jackpot**: each ticket adds its price to the jackpot, which resets to the base amount when won
- **Prize collection**: winnings are paid (cash or bank) the next time the player opens the lottery at a seller
- **Ticket sellers** in Valentine, Strawberry, Blackwater, Armadillo, Rhodes, Saint Denis and Van Horn, with map blips. Peds only spawn when a player is nearby.
- **My Tickets, Past Winners and Info tabs** with a full prize breakdown
- **Discord webhooks** for ticket purchases, draw results, winners and jackpots (the URL is kept server-side)
- **10 languages** through ox_lib locales: en, de, el, es, fr, ja, nl, pl, pt-br, ro
- **RDR2-style dark UI** in the leather and gold theme
- **Exploit-safe**: all checks and money handling happen on the server, with per-player locks so prizes can't be paid twice

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_target](https://github.com/overextended/ox_target)

## Installation

1. Place the `rsg-lottery` folder in your server's resources folder.
2. Import `installation/rsg_lottery.sql` into your database. (The script also creates any missing tables on first start.)
3. Add it to your `server.cfg` **after** its dependencies:
   ```
   ensure rsg-lottery
   ```
4. Optional: add your Discord webhook URL in `server/sv_config.lua`.
5. Optional: set your language in `server.cfg` (see [Languages](#languages)).

## Configuration

### `shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `TicketPrice` | `10` | Cost of one ticket (taken from cash) |
| `NumbersPerTicket` | `5` | How many numbers are picked per ticket, and how many are drawn |
| `NumberMin` / `NumberMax` | `1` / `20` | Range of numbers players can pick |
| `MaxTicketsPerDraw` | `5` | Ticket limit per character per draw |
| `BaseJackpot` | `100` | Jackpot value after it has been won |
| `PayoutMethod` | `'cash'` | `'cash'` or `'bank'`: where prizes are paid |
| `Prizes` | see below | Prize for each number of matches |
| `DrawCron` | `'0 21 * * *'` | Daily draw time as `minute hour * * *` (server time) |
| `TicketSellers` | 7 towns | Ped `model`, `coords` and `heading` for each seller |
| `SpawnDistance` | `60.0` | Distance at which seller peds spawn |
| `Blip` | enabled | `enabled`, `sprite` and `scale` for the map blip |

#### Prizes

```lua
Config.Prizes = {
    [2] = 20,        -- 2 matches = $20
    [3] = 100,       -- 3 matches = $100
    [4] = 200,       -- 4 matches = $200
    [5] = 'jackpot', -- 5 matches = the jackpot
}
```

A match count that isn't listed wins nothing. If several players hit the jackpot in the same draw, it is split evenly between them.

#### Adding a ticket seller

```lua
{
    model = 'u_m_m_nbxshadydealer_01',
    coords = vector3(-326.36, 795.19, 117.89),
    heading = 191.97,
},
```

### `server/sv_config.lua`

This file is never sent to players, so your webhook URL stays private.

```lua
ServerConfig.Webhook = {
    enabled = true,
    url = '',          -- your Discord webhook URL
    color = 10066431,
    footer = 'rsg-lottery',
    footerIcon = '',
    title = '🎟 RSG Lottery',
}
```

## How a draw works

1. Tickets bought **before** the draw time go into today's draw. Tickets bought **after** it go into tomorrow's.
2. At draw time the winning numbers are announced to every player, and every ticket is checked.
3. Winners who are online get a notification. All prizes are stored and appear in the Past Winners tab.
4. Players collect their winnings automatically the next time they open the lottery at any ticket seller.
5. If nobody hits the jackpot, it rolls over to the next draw.

## Languages

All player-facing text (notifications, the target label, the blip name, the UI and webhooks) lives in `locales/*.json`.

Included: `en`, `de`, `el`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`.

Set the language in `server.cfg`:

```
setr ox:locale de
```

To add a language, copy `locales/en.json` to `locales/<code>.json` and translate the values. Keep every `%s` placeholder in place.

## Database tables

| Table | Holds |
|---|---|
| `rsg_lottery_config` | The current jackpot |
| `rsg_lottery_draws` | One row per daily draw: date, jackpot, winning numbers, status |
| `rsg_lottery_tickets` | Every ticket bought |
| `rsg_lottery_winners` | Every prize won, and whether it has been collected |

## Support

If you enjoy this resource, you can support development here: https://buymeacoffee.com/rexshack

## Credits

- RexShack
- RSG Framework, ox_lib, oxmysql, ox_target
