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
