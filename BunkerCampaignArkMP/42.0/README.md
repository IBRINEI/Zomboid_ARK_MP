# Bunker Campaign: The Ark MP Fork

Local multiplayer fork for Project Zomboid 42.19. It copies The Ark's binary
maps, tiles, models and bunker item scripts, while deliberately excluding its
single-player Lua bootstrap and story.

## Enable

- BunkerCampaign
- BunkerCampaignArkMP
- BunkerCampaignIntegration
- Bandits2
- Waterpipes
- BunkerCampaignToxicMP

Do not enable the Workshop mod `TheArk` at the same time.
Do not enable the Workshop mod `ToxicZonesSTALKERB42`; use the local Toxic fork.

## Excluded from the original

- all main-menu and character-creation patches;
- SpawnRegions replacement;
- BWOASequence and BWOAEventControl;
- BWOANPC and permanent story NPCs;
- missions, dialogues, nightmares and scripted finale;
- client-owned world construction and simulation.
- original Bandits NPC definitions, main-menu UI overrides, story AnimSets,
  effects and dialogue/music sound banks.

The excluded binary resources are retained in `_disabled_original_assets` for
local recovery, outside the `common` and `42.0` trees scanned by the game.

The server owns `BanditWeekOneTheArk` compatibility data, tells each joining
client to enter the bunker, waits for the bunker chunks, then builds and
prepares each room once. Room progress is persisted in
`BunkerCampaign.ArkMP`.

Version 0.3.1 restores only the two bunker prefab registrations from the
original `BWOABasements.lua`. They are registered through the B42 Basement API
without loading the original client/story file. Server and client player
coordinates are aligned before streaming the distant basement. This requires
a newly created world.

The original NOAH terminal logic is not loaded yet. Ventilation is controlled
through BunkerCampaign's separate multiplayer-safe context window.
