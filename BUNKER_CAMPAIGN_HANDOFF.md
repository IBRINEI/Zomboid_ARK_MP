# Bunker Campaign handoff

Last updated: 2026-07-29 (Europe/Moscow)

## Read this first

The infrastructure/MP-foundation slice is complete and was accepted in an
administrator + ordinary-client dedicated-server test. The user reported that
everything works as intended and found no remaining defects in this slice.

The stable Ark fork is **BunkerCampaignArkMP 0.4.5**. Versions 0.4.6 through
0.4.10 were lighting experiments made on 2026-07-29 and were deliberately
rolled back. Do not reintroduce those patches. Version 0.4.5 is the known-good
lighting implementation.

Before starting another slice, inspect this file, the two original design
specifications, and the DAG/plan from the originating Codex conversation. Build
the next slice only on top of the stable baseline and in dependency order.

Original specifications:

- `C:\Users\BRINE\.codex\attachments\aa975ebf-d8bd-441e-941e-04df5016cd69\pasted-text.txt`
- `C:\Users\BRINE\.codex\attachments\f49c6ff2-d64b-4220-b4ab-f7edfe582ce5\pasted-text.txt`

## Source and write boundaries

- Target: Project Zomboid Build 42.19.
- Treat `Z:\SteamLibrary\steamapps\common\ProjectZomboid` as read-only.
- Treat `Z:\SteamLibrary\steamapps\workshop\content\108600` as read-only.
- Modify only local forks under `C:\Users\BRINE\Zomboid\mods`.
- Reuse installed mods and their existing systems before writing replacements.
- Never put Cyrillic in in-game/runtime strings; it renders incorrectly.
- Documentation may use any language.
- The original The Ark and Toxic Zones mods must not be enabled alongside the
  local MP forks.

## Git workflow

The Git repository root is `C:\Users\BRINE\Zomboid\mods`. It intentionally
tracks only the four Bunker Campaign local mods and this handoff. Workshop
junctions, unrelated mods, archives, and The Ark recovery-only disabled assets
are excluded by `.gitignore`.

For every future slice:

1. Confirm a clean baseline with `git status --short`.
2. Commit the baseline before risky experiments or use a separate branch.
3. Commit every accepted logical change with its tests and documentation.
4. Do not stage Workshop junctions or files from the game installation.
5. If a test fails, do not commit an alleged completed slice.

## Required mod set and stable versions

Enable:

- Workshop `Bandits2` (read-only dependency).
- Workshop `Waterpipes` (read-only dependency).
- `BunkerCampaign` 0.3.2.
- `BunkerCampaignArkMP` 0.4.5.
- `BunkerCampaignToxicMP` 0.3.4.
- `BunkerCampaignIntegration` 0.5.0.

Disable:

- Original `TheArk`.
- Original `ToxicZonesSTALKERB42`.
- `BanditsDayOne` and `BanditsWeekOne`.
- Cryogenic Winter.

## Completed architecture

### Server-authoritative campaign core

`BunkerCampaign` owns persistent campaign state, validation, event logging,
ventilation, water and power-facing state snapshots. Ordinary players cannot
invoke privileged commands directly. Legitimate physical controls are checked
server-side, including bunker-presence/range requirements.

### Multiplayer The Ark fork

`BunkerCampaignArkMP` reuses The Ark maps, rooms, objects and relevant assets,
but excludes its single-player bootstrap and story architecture:

- no main-menu or character-creation patches;
- no SpawnRegions replacement;
- no permanent story NPCs or `BWOANPC` loop;
- no single-player sequence/event controller;
- no missions, dialogue, nightmares or scripted finale;
- no client-owned bunker construction or simulation.

The server registers the basement prefabs, moves joining characters into the
bunker, waits for the required chunks, constructs/prepares rooms once, records
room progress and supports safe repeated entry. Construction failures latch
instead of spamming every tick, and an administrator can request one retry.

### Toxic Zones MP fork

`BunkerCampaignToxicMP` keeps the installed mod's resources and equipment but
makes zone membership, exposure, mask filtering, filter charge and radiation
death server-authoritative. Filter insertion/removal preserves remaining
charge, needs no crafting surface, and the tooltip displays an English exact
percentage. A replacement character starts with zero exposure.

### Integration and physical systems

`BunkerCampaignIntegration` bridges campaign state to Ark, Toxic Zones and
Waterpipes. Waterpipes remains the owner of the physical pump, pipes, filter,
barrels and flow. The adapter restores the fixed bunker pump when absent and
connects it to the bunker power allocation without recurring command/log spam.

The power layer owns generator requests and resources, consumer allocations,
main-grid status, emergency mode and emergency-battery discharge. Physical
normal and red emergency lights are synchronized for administrator and client.
The stable 0.4.5 behavior is important: later attempts to manipulate room-wide
lighting separately caused permanently illuminated rooms and were rolled back.

## Accepted runtime behavior

The following was manually verified and accepted by the user:

- The Ark setup UI does not appear during character creation.
- Administrator and ordinary client enter the bunker automatically.
- Re-entry and reconnect work without server stalls or anti-cheat kicks.
- The full required bunker structure at levels -4, -5 and -7 is present.
- Toxic zones can be created/removed through authorized controls.
- Exposure rises without a mask and is stopped by a working filtered mask.
- Filter charge falls, is visible in the tooltip, and survives removal/reinsert.
- Radiation death does not carry exposure into the replacement character.
- The bunker water pump, water storage and flow operate without prior log spam.
- Main and backup generators, consumer allocations and emergency battery work.
- Full generator/battery depletion behaves correctly.
- Normal and red emergency lighting behave correctly for both clients.
- Control range/authorization checks work.
- Server restart preserves the physical/system state.
- No remaining defect was reported in this completed slice.

## Tests and diagnostics

Primary manual test document:

- `BunkerCampaignArkMP\42.0\docs\MANUAL_TESTING.md`

Lua regression fixtures are under each mod's `42.0\tests` directory. At the
stable rollback, all Ark MP Lua files passed syntax checking and these suites
passed:

- client entry/teleport/light-manifest regression;
- power-grid lighting regression;
- server entry/construction regression;
- construction-error latch regression.

The Java Lua test runner used by the originating task is under:

`C:\Users\BRINE\.codex\visualizations\2026\07\28\019fa9e3-5b84-7b62-be09-36755b0cfd3a\lua-tests`

## Intentionally not implemented in this slice

These are future design slices, not defects in the accepted foundation:

- the original NOAH terminal experience;
- The Ark single-player story, missions and permanent NPCs;
- later campaign progression/content systems described in the design specs.

Do not restore the original single-player systems wholesale. Any reused feature
must be separated from story/client authority and adapted to the existing
server-authoritative state model first.

## Second slice implementation (awaiting dedicated-server acceptance)

Branch: `slice-2-contamination-decon`.

Implemented after the accepted infrastructure tag:

- `BunkerCampaign` 0.4.0 adds the non-battery-backed `decontamination` power consumer and state migration 3 -> 4;
- `BunkerCampaignToxicMP` 0.4.0 adds server-owned surface contamination for bodies, worn gear and bounded carried inventory scans;
- item contamination persists in modData and is displayed in English tooltips;
- `BunkerCampaignIntegration` 0.6.0 adds the NBC mixer, manual/emergency/automatic cycles, clean-water debit from Waterpipes, power pause/resume and persistent active-cycle state;
- the original Ark room, NBC tablets, reagent locker and map assets are reused without restoring its single-player sequence controller;
- admin-only temporary QA context actions accelerate travel, contamination, resource setup and cycle completion;
- the exhaustive test procedure is `BunkerCampaignIntegration/42.0/docs/SECOND_SLICE_TESTING.md`.

This section records code completion and automated regression results only. Do
not tag the second slice as accepted until the administrator + ordinary-client
dedicated-server procedure passes and the user explicitly accepts it.
