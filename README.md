# gldnrmz-housekeeper

A housekeeping job script for FiveM QBCore servers built off of qb-houserobbery base. Players can enter houses, clean furniture, and earn money (and potentially loot).

## Features

- **House Cleaning Job**: Players can visit various houses to perform cleaning tasks.
- **Interactive Cleaning**: Uses `ox_target` for interaction with furniture (cabinets, shelves, counters, etc.).
- **Immersive Animations**: Custom animations/emotes for different cleaning tasks (dusting, sweeping, wiping).
- **Mess Props**: Visual clutter (mess) appears on furniture that needs cleaning and disappears after cleaning.
- **Multiple Routes**: Supports multiple cleaning routes (Mirror Park, Vinewood, Paleto, etc.) which can be randomized.
- **Configurable Payouts & Loot**: Customize payouts and potential loot drops for each type of furniture cleaned.
- **Optimization**: Uses `ox_lib` and `ox_target` for performance.
- **Job Foreman**: A dedicated NPC (Foreman) to start routes and collect payments.

## Dependencies

- [qb-core](https://github.com/qbcore-framework/qb-core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [qb-interior](https://github.com/qbcore-framework/qb-interior) (for house shells)
- [qb-weathersync](https://github.com/qbcore-framework/qb-weathersync) (optional, for syncing weather inside)
- [interact-sound](https://github.com/plunkettscott/interact-sound) (optional, for door sounds)

## Installation

1. Download the resource and place it in your `resources` folder.
2. Add `ensure gldnrmz-housekeeper` to your `server.cfg`.
3. Ensure all dependencies are installed and started before this resource.

## Configuration

The `config.lua` file allows you to customize various aspects of the script:

- **Config.Routes**: Define the locations of houses to be cleaned. Grouped by routes.
- **Config.CleaningPayouts**: Set minimum and maximum cash payouts for cleaning different furniture types.
- **Config.CleaningLoot**: Configure item drops (chance and amount) for cleaning specific furniture types.
- **Config.DefaultFurniture**: Define the furniture layout, interaction text, and animations for the house interiors.
- **Config.CleaningDuration**: Time it takes to clean a spot.
- **Config.StartPed**: Location of the Job Foreman.

## Usage

1. **Go to the Cleaning Foreman**: Look for the "Cleaning Jobs" blip on the map (default location in Config).
2. **Start Job**: Interact with the foreman (using `ox_target`) and select "Start cleaning route".
3. **Follow Route**: A house will be assigned and marked on your GPS.
4. **Enter House**: Go to the assigned house location and use the target eye to enter.
5. **Clean**: Inside, look for furniture with interaction options (e.g., "Clean cabinet", "Sweep Floor").
6. **Complete**: Once all spots are cleaned, leave the house. If there are more houses in the route, the next one will be assigned.
7. **Get Paid**: Return to the foreman and select "Collect payment" to receive your earnings.

## Events

- `gldnrmz-housekeeper:client:enterHouse`: Triggered when entering a house.
- `gldnrmz-housekeeper:client:ResetHouseState`: Resets the house state.
- `gldnrmz-housekeeper:server:cleanFurniture`: Triggered when a furniture spot is cleaned.
- `gldnrmz-housekeeper:server:CollectPayment`: Triggered to collect payment.

## Credits

- Author: GLDNRMZ
