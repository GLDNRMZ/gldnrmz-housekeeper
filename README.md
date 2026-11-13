# gldnrmz-housekeeper

House cleaning job for Qbox, QBCore and ESX (through community_bridge). Talk to the foreman, get a route of houses, clean every spot in each one, then collect your wages.

## ✨ Features

- **Routes**: 16 routes around Los Santos, Paleto and Sandy. A random one is handed out each time, never the same one twice in a row.
- **Cleaning spots**: 19 spots per house, each with its own animation and synced prop (sponge, broom, mop).
- **Clutter props**: local-only mess on spots that need cleaning, removed as you clean.
- **Wages**: banked per character and collected from the foreman. They survive relogs, crashes and restarts.
- **Loot**: configurable chance to find items or cash on each spot.
- **Server-authoritative**: the server tracks each player's route and checks the order, the player's position and the clean timer before paying. Spoofed events are rejected and logged through `lib.logger`.
- **Recovery**: if you die or get moved out mid-house, go back in and continue where you left off. You can quit a route from the foreman or the front door at any time and keep what you've earned.
- **Clean shutdown**: restarting the resource or logging out removes the shell, zones and props and puts you back outside.

## 📦 Dependencies

- [community_bridge](https://github.com/TheOrderFivem/community_bridge) **0.13.6+** (with [Qbox](https://github.com/Qbox-project/qbx_core), [QBCore](https://github.com/qbcore-framework/qb-core) or [ESX](https://github.com/esx-framework/esx_core) and a supported target / inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [qb-interior](https://github.com/qbcore-framework/qb-interior) (house shell). It doesn't need qb-core, so install it on Qbox and ESX servers too.
- Optional: interact-sound (door sound) and any weather sync that handles `qb-weathersync:client:DisableSync` / `EnableSync` (Renewed-Weathersync does)

## ⚡ Installation

1. Install `qb-interior` and start it, `ox_lib` and `community_bridge` before this resource.
2. Add `ensure gldnrmz-housekeeper` to `server.cfg`.
3. If you use `Config.Loot` items, add them to your inventory's item list.

## ⚙️ Configuration

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

## 🆕 Changes in 2.1.0

- Runs on Qbox, QBCore and ESX through community_bridge.

## 📄 License

**GLDNRMZ Script License** - see [LICENSE](LICENSE).

- ✅ Run it on your own server and edit it for that server
- ❌ Don't sell it, re-upload or share it (free or paid), or put it in a pack or server build
- ❌ Don't remove the credits or claim it as your own

Need something else, like a commercial license? Ask on [Discord](https://discord.gg/7YHJ7774jA).

<!-- gldnrmz-links -->
---

## 🔗 Links

<p align="center">
  <a href="https://discord.gg/7YHJ7774jA"><img src="https://img.shields.io/badge/Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Discord" /></a>
  <a href="https://forum.cfx.re/u/gldnrmz/summary"><img src="https://img.shields.io/badge/Cfx.re-F40552?style=for-the-badge&logoColor=white" alt="Cfx.re forum" /></a>
  <a href="https://5metrics.dev/resources?search=gldnrmz"><img src="https://img.shields.io/badge/5Metrics-00BFFF?style=for-the-badge&logoColor=white" alt="5Metrics" /></a>
  <a href="https://gldnrmz.tebex.io"><img src="https://img.shields.io/badge/Tebex-FFD700?style=for-the-badge&logoColor=black" alt="Tebex store" /></a>
  <a href="https://www.buymeacoffee.com/gldnrmz"><img src="https://img.shields.io/badge/Buy%20me%20a%20coffee-FF813F?style=for-the-badge&logo=buymeacoffee&logoColor=white" alt="Buy me a coffee" /></a>
</p>
