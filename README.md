# gldnrmz-housekeeper

House cleaning job for Qbox, QBCore and ESX (through community_bridge). Talk to the foreman, get a route of houses, clean every spot in each one, then collect your wages.

## Features

- **Routes**: 16 routes around Los Santos, Paleto and Sandy. A random one is handed out each time, never the same one twice in a row.
- **Cleaning spots**: 19 spots per house, each with its own animation and synced prop (sponge, broom, mop).
- **Clutter props**: local-only mess on spots that need cleaning, removed as you clean.
- **Wages**: banked per character and collected from the foreman. They survive relogs, crashes and restarts.
- **Loot**: configurable chance to find items or cash on each spot.
- **Server-authoritative**: the server tracks each player's route and checks the order, the player's position and the clean timer before paying. Spoofed events are rejected and logged through `lib.logger`.
- **Recovery**: if you die or get moved out mid-house, go back in and continue where you left off. You can quit a route from the foreman or the front door at any time and keep what you've earned.
- **Clean shutdown**: restarting the resource or logging out removes the shell, zones and props and puts you back outside.

## Dependencies

- [community_bridge](https://github.com/TheOrderFivem/community_bridge) (with Qbox, QBCore or ESX and a supported target / inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [qb-interior](https://github.com/qbcore-framework/qb-interior) (house shell)
- Optional: interact-sound (door sound) and any weather sync that handles `qb-weathersync:client:DisableSync` / `EnableSync` (Renewed-Weathersync does)

## Configuration

Everything is in `config.lua`:

| Setting | What it does |
| --- | --- |
| `Config.Foreman` | Foreman model, position, scenario and blip |
| `Config.CleanDuration` | Time per spot (ms) |
| `Config.Payout` | Wage range per spot type, payout account and an optional route-completion bonus |
| `Config.Loot` | Loot table per spot type (`default` covers the rest). Use `item` for items or `account` for money |
| `Config.Emotes` | Animation and hand prop for each emote name |
| `Config.Furniture` | Spots inside every house (offsets from the shell origin) |
| `Config.Routes` | Houses grouped into routes |
| `Config.FixedRoute` | Always hand out one route instead of a random one |
| `Config.Debug` | Draw target zones and enable `/housekeeper_offset` |

### Adding a cleaning spot

1. Set `Config.Debug = true` and restart.
2. Start a route, enter a house and stand where the spot should be.
3. Run `/housekeeper_offset`. It copies a `vec3(...)` to your clipboard.
4. Add it to `Config.Furniture`.

Text is in `locales/en.json` (uses `ox:locale`).
