# Bee Forest Pollination Migration Notes

## Legacy cash systems disabled

`ServerScriptService/Main.server.lua` now disables legacy template scripts that look like cash dropper / collector logic.

Keywords used for disable pass:
- `cash`
- `collector`
- `drop`
- `money`

This prevents old cash loops from awarding currency alongside pollination.

## New server-authoritative economy flow

1. Bees are equipped from server-saved inventory.
2. Bee AI flies to plot `PollinationPoints`.
3. Bees add bloom value server-side.
4. Bloom at 100 spawns `MoneyFlower` at `FlowerSpawnPoints`.
5. Player collects via ProximityPrompt (or `CollectFlower` remote), server validates ownership + distance.
6. `EconomyService` awards coins server-side only.
7. Upgrades and zone unlocks spend coins server-side and persist via `DataService`.


## Bee asset source integration

`BeeService` now attempts to clone bee models from:
- `ReplicatedStorage/Assets/BeeModels`

Expected model names:
- `BasicPollinator`
- `SwiftWing`
- `GroveBooster`

Source model pack requested:
- `https://github.com/OkeyToby/robloxstuff/blob/main/Bees%20(1).rbxm`

If models are not present, service uses fallback placeholder parts automatically.


## Forest asset source integration

`Main.server.lua` now attempts to load forest decoration from:
- `ReplicatedStorage/Assets/ForestModels`

Requested source:
- `https://github.com/OkeyToby/house-builder/blob/develop/trees.rbxm`

All `Model` / `BasePart` / `Folder` children are cloned into `Workspace/ForestTheme`.
If none are found, fallback trees are generated server-side.


## Background music integration

`Main.server.lua` now configures looped background music in `SoundService`:
- Preferred source: `ReplicatedStorage/Assets/Music/BiernesDans` (Sound instance)
- Requested source track: `https://github.com/OkeyToby/robloxstuff/blob/main/Biernes%20Dans.mp3`

When present, the `BiernesDans` sound is cloned to `SoundService/BeeForestBackgroundMusic` and played server-side.
If missing, playback is skipped and the server logs an actionable warning.


## Startup image + thumbnail notes

A client loader screen has been added in `StarterPlayerScripts/LoadingScreen.client.lua`.
It reads image id from `ReplicatedStorage/Assets/Images/LoaderImage` (`StringValue`).

Roblox thumbnail is configured outside runtime scripts (Creator Dashboard), so use the same uploaded image there.
