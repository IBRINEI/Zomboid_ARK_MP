# Bunker Campaign handoff

Last updated: 2026-07-30 (Europe/Moscow)

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

## Remaining work inside the second slice

The current manual-wash implementation is an explicitly accepted temporary
fallback, not the final design. Bunker-water manual cleaning is an immediate
server transaction because custom timed actions are unreliable in Build 42.19.
Washing at an ordinary water source uses the vanilla shared timed action and
applies radioactive cleaning from its authoritative server `complete()`.

Complete the remaining work in the following dependency order.

### S2.1. Hazard-zone data model

- Extend a zone beyond the current name + rectangle representation. Persist at
  least its airborne intensity, surface-deposition intensity, external dose
  rate or an explicit zero value, contamination type, vertical bounds and
  overlap priority.
- Keep the design specification's hazard channels separate. A gas mask/filter
  may mitigate airborne exposure, but it must not silently protect against
  external radiation. Surface deposition must remain a separate value.
- Define deterministic overlap and boundary behavior before placing real
  zones. Zone data must remain server authoritative, bounded and safely
  migratable from existing `ToxicZone` data.
- Make the rates consume the zone values: airborne exposure, body/gear/item
  deposition and the zone-dependent part of filter drain. Preserve a small
  baseline filter drain whenever a mask is worn, as already accepted by the
  user.

### S2.2. Real map placement and level tuning

- Replace the single temporary exterior QA rectangle with a version-controlled
  zone manifest for the actual campaign map.
- Survey the bunker surroundings and important settlements, industrial,
  scientific and military destinations before committing coordinates. Reuse
  useful zone/map data from installed mods where possible.
- Place and tune the intended progression rings: moderate bunker surroundings,
  nearby settlements, high-intensity industrial areas, scientific/military
  hotspots and deep-expedition areas.
- Explicitly protect the bunker interior, entry transition and intended safe
  routes from accidental surface-zone overlap. Test every boundary on all used
  Z levels.
- Calibrate rates with real travel times, physical activity, mask condition,
  filter capacity and return/decontamination costs. The result must not be a
  set of arbitrary levels that was tested only with QA teleporting.

### S2.3. Final manual decontamination workflow

- Replace the instant bunker fallback with a Build-42-safe, time-consuming
  workflow. Do not reintroduce the removed custom timed actions or
  `forceComplete()` workaround without first proving their dedicated-server
  synchronization.
- Prefer a server-owned job/deadline with client presentation, or a proven
  shared vanilla action whose server `complete()` owns the transaction. Define
  cancellation, movement, damage, death, disconnect and reconnect behavior.
- Calculate duration, water and cleaning-agent use per target rather than only
  from one contamination percentage. Account for item category, covered body
  area/size, layers, material or an explicit material class, and contamination
  amount.
- Make body washing longer than washing one ordinary garment and give it its
  own resource formula. Large coats, full suits, footwear and backpacks must
  cost more than small garments; tiny items must cost less.
- Decide and document whether manual cleaning is all-or-nothing or progressive.
  Resource reservation/consumption and cleaning must be one authoritative
  transaction, including interruption and two players attempting operations
  at the same time.
- Use the same cost model at the bunker chamber and ordinary water sources,
  while preserving their different water owners. Keep the chamber's instant
  operation only until this replacement passes MP testing.

### S2.4. Consequences and feedback for contamination

- Surface contamination currently persists, transfers and drives clean-side
  warnings, but needs explicit gameplay consequences. Define bounded secondary
  exposure/contact effects and thresholds without conflating it with airborne
  exposure or external dose.
- Finish the dirty/chamber/clean-area loop: contaminated players and objects
  raise local contamination, local contamination can affect later occupants,
  and successful cleaning reduces the authoritative room value.
- Show the zone level/hazard channels and relevant protection result clearly
  enough to explain why exposure, deposition and filter drain differ. Runtime
  strings must remain English.
- Review protective clothing coefficients so coverage/material/condition can
  affect deposition and later manual-cleaning cost without scanning every item
  against every other item each tick.

### S2.5. Balance, regression and slice closure

- Add automated tests for zone migration, overlap priority, intensity-scaled
  rates, manual-job interruption, exact per-item resource debit and duplicate
  completion/reconnect protection.
- Repeat dedicated-server acceptance with an administrator and ordinary
  client: zone boundaries, several hazard levels, body versus garment timing,
  concurrent attempts, death, reconnect and server restart.
- Remove the temporary test zone from normal campaign initialization. Keep QA
  teleport/create/remove/resource actions administrator-only and clearly
  temporary until the slice is accepted.
- Update the complete and retest documents with the final zone manifest,
  formulas and measured expected values. Only then tag the second slice as
  accepted.

The following design items are deliberately outside this slice unless the user
later changes the boundary: vehicle/cargo decontamination, filter regeneration,
radiation medicines and long-term dose treatment, weather-driven moving zones,
protective-suit repair progression, skill/specialization bonuses, and campaign
missions/unlocks. The second-slice data model should leave room for them but
must not implement them prematurely.

## Third slice implemented: extensible water and ventilation (2026-07-30)

The user accepted the preceding playable slice and authorized the complete
water/ventilation implementation. Work is on branch `slice-3-life-support`.
This section records implementation and automated validation; dedicated MP
acceptance is still pending.

Implemented versions:

- `BunkerCampaign` 0.5.0, persistent state version 6;
- `BunkerCampaignIntegration` 0.7.0, integration state version 4;
- `BunkerCampaignToxicMP` 0.5.0;
- the accepted `BunkerCampaignArkMP` lighting behavior remains untouched.

The new `RoomRegistry` is data-driven. Integration automatically imports every
bounded negative-Z ArkMP room and derives volume, vent weight and adjacency.
Addon rooms can instead call `CampaignState.registerRoom`. The water and air
simulations iterate the registry, so future garage, laboratory, workshop or
storage rooms do not require named branches in those systems.

There is now one ordered server lifecycle: room/occupant discovery, external
sampling, power-demand preparation, power allocation, physical actuation,
simulation, effects and snapshot publication. This removes the previous race
where a pump could be evaluated before bunker power existed.

Ventilation now models five modes, independent Ark intakes, real contaminated
airflow, filter loading, fan/intake availability, per-room CO2 and airborne
contamination, room leakage/mixing and a persistent airlock purge. Internal
air contamination is provided to ToxicMP, which remains the sole owner of
player exposure and mask-filter drain. High-CO2 effects are server owned.

Water now distinguishes requested, allocated, physically available and actual
operation. It models well/external/collected/portable sources, pump and
treatment condition/faults, bypass, clean/tainted storage and telemetry.
Waterpipes remains canonical for physical topology, volumes, types, filter and
pump wear. Decontamination consumes through the new server-owned WaterService;
persisted transaction ids prevent duplicate debit.

Architecture and extension contract:
`BunkerCampaign/42.0/docs/LIFE_SUPPORT_ARCHITECTURE.md`.

Dedicated MP acceptance procedure:
`BunkerCampaignIntegration/42.0/docs/THIRD_SLICE_TESTING.md`.

### Third-slice MP correction pass (2026-07-30)

The first manual pass found stale room occupancy, unbounded vertical QA zones,
two conflicting hard-coded zone buttons, cached intake hazards, drainable
ventilation cartridges incorrectly mapped to item condition, no entry-door
breach state, opaque purge progress and Waterpipes controls that were
overridden by campaign authority.

Patch versions are Core 0.5.1, ArkMP 0.4.5.1, ToxicMP 0.5.1 and Integration
0.7.1. Occupancy now resets from the current online-player sample. Zones carry
explicit Z bounds and the unified admin QA menu places a single-level zone
around the selected tile or directly over surface intakes. ToxicMP notifies the
integration immediately after any zone mutation. The vanilla drainable
`Base.GasmaskFilter` now preserves `UsedDelta`/Remaining and is never charged
through Condition. ToxicMP mask recipes and bunker ventilation now consume the
same vanilla filter type; the former non-drainable `Base.GasMaskFilter` remains
defined only so existing saved items do not disappear.

The integration samples all three Ark entrance doors. A completely open,
fully loaded path is reported as `BREACHED`, permits direct exterior exchange
into the entrance/decontamination rooms and pauses purge until containment is
restored. The systems panel reports current-room CO2/contamination/occupancy,
worst-room values, entry-path state, filter use per minute and purge progress.
The physical pump tile now changes the same authoritative request as the
systems panel. The admin QA water submenu creates clean, tainted, empty,
damaged-filter, damaged-pump and finite-external-source test states.

### Third-slice room/air/water correction pass (2026-07-31)

Core 0.5.2 and Integration 0.7.2 address the second dedicated-server test
report. Ark's corridor has no rectangular bounds, so it is now registered as
one declarative five-region ventilation room. The registry, snapshots, player
lookup and adjacency model support composite footprints; this is also the
extension mechanism for later non-rectangular garage/laboratory additions.
The systems window has a persistent scrollable room map listing every room's
CO2, airborne contamination, occupants, airflow and connections.

A serviceable ventilation filter now blocks contaminant breakthrough until it
is exhausted or fails. Filter charge is consumed only while capturing dirty
outside air or cleaning dirty recirculated air, and explicit activity/removal
telemetry explains an unchanged percentage in clean air. Recirculation cleans
internal airborne contamination but does not remove CO2. Sealed has no
intentional outside exchange; Off retains passive leakage. The emergency fan
load fits the healthy backup generator's life-support budget without shedding
main lights. Trace contamination from the former partial-breakthrough model is
cleared and no longer reaches ToxicMP player exposure.

Entry telemetry now uses an explicit four-gate manifest: one surface gate and
three bunker gates. Reports distinguish open, loaded and total counts. The
four physical surface intakes are listed with coordinates and can be broken or
repaired individually from the administrator context menu on their exact
tiles.

QA reports are persistent scrollable windows; water reports contain only
water state. The empty-water command is promoted, clearly labelled and stops
the pump so the infinite well cannot immediately refill the test state. Clean,
tainted and empty storage mutations now update loaded Waterpipes sinks and
containers directly as well as unloaded pending buffers, so a tainted QA fill
is observable from a sink immediately and emptying storage drains the actual
receiver.

Integration 0.7.3 is a startup hotfix for the physical receiver adapter.
WaterPipes returns pre-shutoff sink amounts from sprite properties as strings;
the adapter now normalizes both amount and capacity before comparison. A
string-valued receiver regression test covers the former per-tick `__lt not
defined for operand` failure.
