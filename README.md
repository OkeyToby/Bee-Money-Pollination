# Bee Money Pollination

Server-authoritative Roblox tycoon conversion from cash collector template to bee pollination loop.

## Required workspace structure

Place plots under `Workspace/Plots`.
Each player plot should be named to match the player name (or your own assignment flow should rename/clone appropriately).

Inside each plot create:
- `PollinationPoints` (Folder)
  - Children: Parts used as pollination targets.
  - Each point receives `Bloom` + `BloomRateMultiplier` NumberValues automatically.
- `FlowerSpawnPoints` (Folder)
  - Children: Parts where `MoneyFlower` may spawn.

If no points exist, `Main.server.lua` creates starter placeholders.

## Remote events

Created in `ReplicatedStorage/Remotes`:
- `CollectFlower`
- `BuyUpgrade`
- `EquipBee`
- `UnlockZone`
- `SyncState` (server -> client state snapshot/feedback)

## Modules

`ReplicatedStorage/Modules`:
- `DataService.lua`
- `EconomyService.lua`
- `BeeService.lua`
- `PollinationService.lua`
- `UpgradeService.lua`
- `ZoneService.lua`

## Gameplay notes

- Currency is never trusted from client.
- Flower collection validates ownership + distance on server.
- Upgrades and zone unlocks validate coin costs on server.


## Bee model asset (required)

Use the provided bee model pack:
- `https://github.com/OkeyToby/robloxstuff/blob/main/Bees%20(1).rbxm`

In Roblox Studio:
1. Download the `.rbxm` file.
2. Import model into `ReplicatedStorage`.
3. Create folder `ReplicatedStorage/Assets/BeeModels`.
4. Move bee models into `BeeModels` and name them to match bee IDs used by code:
   - `BasicPollinator`
   - `SwiftWing`
   - `GroveBooster`

If these models are missing, the game falls back to simple neon part bees so gameplay still works.


## Forest model asset (required)

Use the provided forest/tree pack:
- `https://github.com/OkeyToby/house-builder/blob/develop/trees.rbxm`

In Roblox Studio:
1. Download `trees.rbxm`.
2. Import into `ReplicatedStorage`.
3. Create `ReplicatedStorage/Assets/ForestModels`.
4. Move imported tree/forest models into `ForestModels`.

`Main.server.lua` clones everything from `ReplicatedStorage/Assets/ForestModels` into `Workspace/ForestTheme` at runtime.
If missing, a simple fallback forest is generated automatically.


## Background music asset (required)

Use the provided track:
- `https://github.com/OkeyToby/robloxstuff/blob/main/Biernes%20Dans.mp3`

Recommended Roblox Studio setup:
1. Download `Biernes Dans.mp3`.
2. Import the audio into Roblox (so it gets a valid `rbxassetid://...`).
3. In Explorer, create `ReplicatedStorage/Assets/Music`.
4. Add a `Sound` named `BiernesDans` inside that folder and set its `SoundId` to your uploaded asset id.

Runtime behavior:
- `Main.server.lua` clones `ReplicatedStorage/Assets/Music/BiernesDans` into `SoundService` as `BeeForestBackgroundMusic` and starts playback.
- If `BiernesDans` is missing, music stays disabled and the server logs a warning (Roblox requires uploaded audio asset IDs).


## Loader image + thumbnail setup

You asked for a startup image while loading and as thumbnail.

### In-game loader image
- `StarterPlayerScripts/LoadingScreen.client.lua` shows a full-screen loader at game start.
- Set loader image by creating `ReplicatedStorage/Assets/Images/LoaderImage` (`StringValue`) with value like `rbxassetid://1234567890`.
- Loader auto-hides when first `SyncState` payload arrives (or after timeout fallback).

### Roblox game thumbnail
Thumbnail cannot be changed by runtime script.
Set it in Creator Dashboard / Game Settings using the same uploaded image asset.


## VS Code sync / overførsel

Hvis du ikke kan få projektet over i VS Code, brug denne hurtige workflow:

1. **Push repo til GitHub**
   ```bash
   git remote add origin https://github.com/OkeyToby/Bee-Money-Pollination.git
   git push -u origin work
   ```
2. **Klon repo i VS Code**
   - VS Code → *Source Control* → *Clone Repository*
   - Indsæt repo URL og åbn mappen
3. **(Roblox Studio ↔ VS Code)** Brug evt. Rojo for live sync
   - Installer Rojo plugin i Roblox Studio
   - Installer Rojo CLI lokalt
   - Brug repoets `default.project.json` (allerede tilføjet)
   - Kør `rojo serve` og connect fra Studio

> Bemærk: `.rbxl/.rbxlx` place-filer synkroniseres ikke automatisk kun via Git. Koden i denne repo er script-kilde, og assets (models/audio/images) importeres i Roblox Studio som beskrevet ovenfor.
