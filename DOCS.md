# rsg-lottery — Developer Docs

## Dependencies
- `rsg-core` (locales, notify, callbacks, RequestModel)
- `rsg-target` (seller ped interaction)
- `oxmysql`

No ox_lib dependency. The resource was migrated off ox_lib to rsg-core.

## Locales
Loaded with `@rsg-core/shared/locale.lua`; strings in `locales/*.json`, read with `locale('key', ...)`.
Language is set by the `rsg:locale` convar (falls back to `ox:locale`, then `en`).

## Server callbacks (`RSGCore.Functions.CreateCallback`)
| Name | Args | Returns |
|---|---|---|
| `rsg-lottery:server:buyTicket` | `numbers` (table) | `true`/`false` |
| `rsg-lottery:server:collectPrizes` | – | total collected (number) |
| `rsg-lottery:server:getMyTickets` | – | `{ { ticket, numbers } }` for the open draw |
| `rsg-lottery:server:getJackpotInfo` | – | jackpot, price, limits, countdown, prize table |
| `rsg-lottery:server:getPastWinners` | – | last 50 winners |

The client calls these with `RSGCore.Functions.AwaitCallback`. Only the callbacks listed in `NUI_CALLBACKS` (plus `buy`) can be reached from the NUI, and the server validates all purchase input.

## Notifications
Server → client: `TriggerClientEvent('RSGCore:Client:Notify', src, { title, description, type, duration })`.
Client: `RSGCore.Functions.Notify({...})`.

## Draw scheduling
`Config.DrawCron` (`'min hour * * *'`) is scheduled with `RSGCore.Functions.CreateCron` (rsg-core's replacement for `lib.cron`), which calls `runDueDraws()`. The task stops automatically when the resource stops. Draws missed while the server was offline are run on startup.

## Seller peds
Each `Config.TicketSellers` entry is an rsg-core point (`@rsg-core/client/points.lua`, which replaces `lib.points`). Peds spawn inside `Config.SpawnDistance` (default 60.0) and despawn outside it. Each ped gets a `rsg-target` `addLocalEntity` option that opens the UI.

## Database
Tables (`rsg_lottery_config`, `rsg_lottery_draws`, `rsg_lottery_tickets`, `rsg_lottery_winners`) are created automatically on start. A manual import is also available in `installation/rsg_lottery.sql`.

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-lottery 3.0.1**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `oxmysql`, `rsg-target`

### Database

Tables: `rsg_lottery_config`, `rsg_lottery_draws`, `rsg_lottery_tickets`, `rsg_lottery_winners`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg_lottery.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.TicketPrice` | `10` |  |
| `Config.NumbersPerTicket` | `5` |  |
| `Config.NumberMin` | `1` |  |
| `Config.NumberMax` | `20` |  |
| `Config.MaxTicketsPerDraw` | `5` |  |
| `Config.BaseJackpot` | `100` |  |
| `Config.PayoutMethod` | `'cash'` | cash or bank (how prizes are paid out) |
| `Config.Prizes` | `table` | matched numbers = prize in $ ('jackpot' = share of the jackpot) |
| `Config.DrawCron` | `'0 21 * * *'` | daily draw time in 'minute hour * * *' format (server time) |
| `Config.TicketSellers` | `table` |  |
| `Config.SpawnDistance` | `60.0` | peds spawn when a player is within this distance |
| `Config.Blip` | `table` |  |

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-lottery:server:buyTicket` | server | `src, cb, numbers` | `server/server.lua` |
| `rsg-lottery:server:collectPrizes` | server | `src, cb` | `server/server.lua` |
| `rsg-lottery:server:getMyTickets` | server | `src, cb` | `server/server.lua` |
| `rsg-lottery:server:getJackpotInfo` | server | `src, cb` | `server/server.lua` |
| `rsg-lottery:server:getPastWinners` | server | `_, cb` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-lottery:server:buyTicket', function(result)
    -- use result
end, numbers)
```

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
