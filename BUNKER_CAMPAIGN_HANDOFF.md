# Bunker Campaign handoff

Last updated: 2026-08-01 (Europe/Moscow)

## Read this first

The infrastructure/MP-foundation, extensible life-support and physical-heating
slices are complete. Their Build 42.19 acceptance remains the gameplay
baseline. A Build 42.20 compatibility audit was completed on 2026-08-01; read
the dedicated audit section at the end of this file before starting more work.
Do not reopen completed slices for unrelated campaign features; start the next
dependency-ordered slice instead.

The packaged Ark fork is **BunkerCampaignArkMP 0.4.5.3** and retains the
known-good 0.4.5 lighting implementation. Versions 0.4.6 through 0.4.10 were
lighting experiments made on 2026-07-29 and were deliberately rolled back. Do
not reintroduce those patches. The 0.4.5.3 suffix contains only Build 42.20
compatibility and metadata changes.

Before starting another slice, inspect this file, the two original design
specifications, and the DAG/plan from the originating Codex conversation. Build
the next slice only on top of the stable baseline and in dependency order.

Original specifications:

- `C:\Users\BRINE\.codex\attachments\aa975ebf-d8bd-441e-941e-04df5016cd69\pasted-text.txt`
- `C:\Users\BRINE\.codex\attachments\f49c6ff2-d64b-4220-b4ab-f7edfe582ce5\pasted-text.txt`

## Source and write boundaries

- Target: Project Zomboid Build 42.20 (verified against 42.20.0,
  `a2947723ca`, Steam build 24449119).
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
tracks the six Bunker Campaign local mods and this handoff. Workshop junctions,
unrelated mods, archives, and The Ark recovery-only disabled assets are excluded
by `.gitignore`.

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
- `BunkerCampaignBuild42Compat` 0.1.0 (required first on Windows Build 42.20).
- `BunkerCampaign` 0.7.1.
- `BunkerCampaignArkMP` 0.4.5.3 (0.4.5 lighting baseline).
- `BunkerCampaignToxicMP` 0.5.1.
- `BunkerCampaignIntegration` 0.8.2.
- `BunkerCampaignThermalJava` 0.2.0 (optional thermal bridge).

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
The stable 0.4.5 lighting behavior is important: later attempts to manipulate
room-wide lighting separately caused permanently illuminated rooms and were
rolled back.

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

## Third slice: extensible water and ventilation (accepted 2026-08-01)

The user accepted the preceding playable slice and authorized the complete
water/ventilation implementation. Work is on branch `slice-3-life-support`.
The implementation, correction passes and dedicated MP acceptance are recorded
below. The slice is closed; remaining campaign work belongs to later slices.

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

### Third-slice telemetry and WaterPipes synchronization pass (2026-07-31)

Core 0.5.3 and Integration 0.7.4 address the next live MP report. The room-air
window now requests and renders fresh authoritative snapshots every two
seconds while open. CO2 remains volume-aware: generation per occupant is
divided by each registered room's composite footprint area times height.
Recirculation reports a high-precision removal fraction and contaminated-air
equivalent m3/min. Intake normalization forces failed units to condition 0;
the UI separates internal fallback flow from zero outside-intake flow.

Broken surface intakes now have a normal server-authoritative repair path.
Any player can stand next to the exact intake tile and perform a timed repair
using one `Base.ScrapMetal`; the server revalidates the tile, distance, broken
state and inventory debit. Administrator instant break/repair actions remain
available for QA.

The local integration patches WaterPipes repair completion so repaired pump
efficiency reaches its server ModData instead of being overwritten when the
pump is next activated. Water snapshot publication now includes condition,
filter, contamination and active-state changes, keeping the bunker panel in
sync with WaterPipes. Treatment filter use is additionally debited from actual
liters moved against a 1000 L full-charge capacity and is shown with sufficient
precision. Administrator QA can set the real treatment filter to 0%, and the
tainted-fill action stops the pump first. Physical receivers retain their
actual water-medium marker so a tainted sink does not silently become clean
when WaterPipes drains its pending buffer.

### Third-slice mode separation and tainted-fluid pass (2026-07-31)

Core 0.5.4 and Integration 0.7.5 make the three closed-air modes observable
and mechanically distinct. Off now exposes measurable passive outside leakage;
Sealed has no outside exchange and only minimal passive room mixing; Internal
recirculation consumes fan power, moves 450 m3/min internally, performs fast
volume-conserving mixing and cleans airborne contamination without fresh air.
The panel reports outside exchange and room-mixing rate explicitly. Filter
activity is derived from the actual per-minute charge delta, so a falling
percentage can no longer be paired with `no_filter_load`.

The Ark intentionally initializes `intake_1` as failed. Intake context menus
now display exact id/status/condition, and the ordinary timed repair sends its
server request from Build 42's `perform()` path instead of waiting forever in
an unused completion path. Right-clicking the air-vent room now opens a compact
status submenu with active/requested modes, restriction, hardware, intakes,
airflow, filter use and CO2.

WaterPipes 42.19 hard-codes `FluidType.Water` when its receiver is backed by a
FluidContainer, even when the virtual pipe medium is `TaintedWater`. The
integration now replaces only that tainted bunker-receiver branch, adding real
`FluidType.TaintedWater` and preserving the physical marker. Other WaterPipes
networks and clean-water synchronization remain on the original code path.

### Third-slice network/action correction pass (2026-07-31)

Core 0.5.5 and Integration 0.7.6 close the final Build 42.19 multiplayer
action and snapshot races. Campaign-state publication is deferred while the
ordered life-support minute is running, then emitted once with the final power,
ventilation and water values. A startup guard skips the global packet send when
there are no online players, avoiding the dedicated-server `udpEngine` failure.
The client ignores snapshots older than its current numeric revision. Rapid
server/client polling no longer observes intermediate zero-valued telemetry.

Build 42.19 reconstructs network timed actions differently when a custom
client-only action defines `complete()`. Removing that method from
`BunkerCampaignRepairIntakeAction` makes the normal `perform()` path reliable:
the real queued action completes, consumes one `Base.ScrapMetal`, reaches the
authoritative server validation and repairs the selected intake. Do not add a
custom `complete()` or `forceComplete()` workaround back to this action.

Tainted sink water required corrections on both sides. The client constructor
patch passes the replicated per-object `BunkerCampaignWaterMedium` marker into
`ISTakeWaterAction` without mutating shared sprite properties. On the server,
`WaterTakeActionServerPatch.lua` replaces only the marked legacy-sink transfer:
the source is debited through the vanilla temporary-container operation, then
the bottle or drinking sample receives `FluidType.TaintedWater`. Clean and
unrelated sources remain on the vanilla transfer path. This server module was
confirmed to load normally after a clean restart.

Regression coverage added in this pass:

- out-of-order client snapshot rejection;
- empty-player startup broadcast guard;
- one atomic end-of-minute state publication after adapter mutations;
- Build 42.19 intake-action shape without `complete()`;
- authoritative client water-medium selection;
- tainted server transfer plus untouched clean-water fallback.

Runtime acceptance used correlation id `zb-fix-20260731-05`. Twenty-four rapid
polls matched server/client revision and telemetry, the real intake action
completed and consumed its material, and a real multiplayer water action filled
the test bottle with primary fluid `TaintedWater`. The test item was removed and
the player was returned to the bunker afterwards. Commit: `0d1490c`.

### Third-slice full-storage/filter correction (2026-07-31 to 2026-08-01)

Core 0.5.6 and Integration 0.7.7 fix phantom water production and duplicate
treatment-filter debit. WaterPipes keeps its flowmeter at nominal pump
throughput even when every bunker receiver is full. The adapter now exposes
only accepted flow, clamped to the free physical storage capacity for the next
minute. The core water simulation applies the same capacity bound before
production telemetry or finite-source debit. Consequently a powered pump
against a full reserve reports `storage_full`, accepted flow 0, campaign filter
use 0 and no increase in produced liters.

The original read-only WaterPipes mod still performs its own very slow native
pump/filter wear while a pump is active. That behavior remains intentionally
owned by WaterPipes. The removed defect was the campaign adapter charging the
same filter again for nominal flow that stored no water.

Automated regressions assert that a full physical reserve reports zero accepted
flow, does not call the campaign treatment debit and does not add phantom core
production. Syntax checks and the focused life-support and WaterPipes adapter
suites pass. Commit: `d313569`.

After a clean server/client restart on 2026-08-01, both permanent patches were
present in the loaded-file set. With the pump on and storage set to 520 L clean:

- status remained `operational` with reason `storage_full`;
- accepted flow and campaign filter use remained 0;
- produced liters were unchanged over the accelerated-time observation;
- 12 snapshot samples stayed complete, and an explicit normal `requestState`
  returned an exact server/client revision and payload match;
- no Bunker Campaign errors appeared after the test correlation marker.

The test state was restored through the existing administrator controls. The
player was left at `9966,12622,-4`; storage was 520 L clean and 0 L tainted;
the treatment filter was restored to effectively 100%; the main generator was
running and refueled, and the idle backup generator was at 100% fuel.

### Third-slice closure and forward constraints

The user explicitly accepted the third slice on 2026-08-01. Its closure covers:

- data-driven rectangular and composite room registration for future rooms;
- per-room volume-aware CO2, contamination, occupancy and live room-map UI;
- distinct Off, Sealed, Internal Recirculation, External Filtration and
  Emergency ventilation behavior;
- four physical intakes, entry breach state, repair and airlock purge;
- authoritative power allocation and physical generator/light integration;
- authoritative pump request, physical condition, source, filter, clean/tainted
  storage, sink medium and decontamination water transactions;
- administrator QA controls and restart-safe multiplayer synchronization.

Relevant third-slice commit sequence:

- `47e197d` - extensible bunker life support;
- `715a720` - life-support state and administrator QA corrections;
- `d2946bf` - room airflow and physical-water QA;
- `eadb0cd` - WaterPipes sink-value normalization;
- `3aa4da3` - life-support telemetry and water synchronization;
- `847e426` - ventilation-mode separation and tainted tap water;
- `0d1490c` - atomic synchronization and multiplayer water actions;
- `d313569` - full-storage flow and treatment-filter correction.

Known non-blocking observations at closure:

- server startup still logs missing third-party item ids such as `Base.Soap`,
  `Base.DentalFloos`, `Base.MufflerPerformance*` and `Base.TomatoBagSeed`; these
  originate in reused external content and did not affect this slice;
- `BunkerCampaignIntegration/42.0/docs/THIRD_SLICE_TESTING.md` has an unrelated
  pre-existing accidental pasted block in the working tree. It was deliberately
  excluded from all accepted commits. Repair it separately from a known-good
  copy instead of staging it with gameplay work.

No further restart is required for the accepted versions. Begin subsequent
work from commits `0d1490c` and `d313569`, preserve the read-only dependency
boundary, and keep all runtime strings in English.

## Fourth slice candidate: fallout climate and bunker heating (2026-08-01)

Development is isolated on branch `slice-4-heating`. This is a candidate for
the fourth slice, not yet user-accepted. The stable third-slice branch and its
accepted versions remain unchanged.

Candidate versions:

- `BunkerCampaign` 0.7.0, campaign state version 8;
- `BunkerCampaignIntegration` 0.8.2, integration state version 5;
- optional `BunkerCampaignThermalJava` 0.2.0;
- `BunkerCampaignArkMP` 0.4.5.2 (the accepted 0.4.5 behavior plus the
  reconnect-light repair; none of the rejected 0.4.6--0.4.10 changes);
- `BunkerCampaignToxicMP` remains exactly 0.5.1.

The dependency order is now explicit. The server first evaluates the reused
The Ark two-sided sine fallout curve from the existing `SandboxVars.BWOA`
options. It records base outdoor temperature, fallout offset, authoritative
outdoor temperature, wind and precipitation. Only after that does the core
calculate per-room heat loss and heating demand; power allocation then decides
whether the heat exchanger can operate. This avoids the earlier architectural
mistake of introducing a powered appliance before its energy model.

The core owns persistent heating state, target temperature, heat-exchanger and
pipe condition, per-room temperature, room circuit isolation, demand, output,
loss and failure reasons. Heating is an explicit 65-priority consumer: it is
shed before the already accepted water and main-lighting loads because thermal
inertia gives it more tolerance than those immediate services. A cold bunker
can exceed backup capacity while every other load is requested; operators must
then shed lower-priority loads or restore the main generator. That behavior is
observable in the systems panel rather than hidden.

The integration reuses The Ark's room vents and its `+7 C` local heat-source
correction. It deliberately replaces the original client-owned radius-1000
sources with replicated, removable radius-5 `IsoHeatSource` objects at actual
vent coordinates on both server and client. Those sources remain useful for
the physical vent representation, but Build 42.19's
`ClimateManager.getAirTemperatureForSquare` hard-clamps powered indoor rooms
to 22 C and heat sources can only raise that result. They therefore cannot make
a room colder than 22 C: the systems panel could correctly show -41 C while a
wristwatch and the character thermoregulator still received 22 C.

The Java patch is now a physically separate optional mod,
`BunkerCampaignThermalJava` 0.2.0. The client listens for the normal core
heating snapshot; the server reads the authoritative campaign state after
initialization/start and every game minute. Each side atomically publishes
every exact RoomRegistry region and its server-authoritative temperature. The
patched ClimateManager method replaces the vanilla value only inside those
regions. Consequently wristwatches, server-owned thermoregulation, cold
moodles and other vanilla square-temperature consumers share the same room
value instead of receiving a UI-only substitute. The same runtime JAR loads on
both client and dedicated server because Build 42.19 skips local-player
`BodyDamage.Update()` on an MP client and performs the authoritative body
simulation on the server. Source, Lua lifecycle adapters and tests all live
exclusively under `BunkerCampaignThermalJava/42.0`; the JAR SHA-256 is
`44CA0AF45AC03477446F2719A3CA3E9A8980A6C6D00217952505E874F313C3E4`.

`BunkerCampaignIntegration` 0.8.2 contains no Java classes, no Java JAR, no
thermal-registry calls and no ZombieBuddy dependency. Disabling or removing
only `BunkerCampaignThermalJava` therefore restores vanilla indoor temperature
reporting without removing fallout climate, the server heating simulation,
vent heat sources, power, ventilation, water, decontamination, Toxic Zones or
ArkMP behavior. The original Ark `ventilation.temp`, `tempTarget` and heating
request remain one-time compatibility imports/mirrors.

The subscribed Workshop ZombieBuddy package currently contains framework
2.3.2, while the already installed game-root Java agent reports
3.0.0-alpha. Do not overwrite the newer `ZombieBuddy.jar` or `zbNative.dll`
in the read-only game installation with that older Workshop binary. The
repository instead tracks `ZombieBuddy/42/mod.info`, a minimal local PZ mod
marker with `id=ZombieBuddy`. It satisfies the optional ThermalJava mod's
documented `require=\ZombieBuddy` dependency while leaving the active
3.0.0-alpha agent as the only framework runtime. Local client
`mods/default.txt` and dedicated server `Server/servertest.ini` include
`ZombieBuddy`; they also include `BunkerCampaignThermalJava` as the final,
independently removable mod. Those two machine-specific files remain outside
the project commits.

The reconnect lighting fault was separate from heating. Save/stream reload
stripped the battery flag from all 653 expected red emergency switches, so the
old classifier treated them as main lights and the client could display red and
main lighting together. ArkMP 0.4.5.2 now identifies emergency lights by their
immutable The Ark room coordinate plus directional sprite, repairs their
battery identity on server and client, and builds the reconnect manifest from
that stable role. A live server audit after applying the repair found 194 main
and 653 emergency lights, with every emergency light repaired and no role
overlap.

The Bunker Systems panel now contains heating enable/disable, 0.5 C target
adjustment, current-room circuit isolation, average/outdoor/current/coldest
temperature, thermal output/loss and power demand. All runtime strings in both
EN and RU translation files are English.

Automated coverage passing on this branch:

- power allocation and backup shedding;
- heating normalization, demand, room loss/mixing, failures and room control;
- state 6 -> 7 and 7 -> 8 migrations plus server command validation;
- ventilation, water and full life-support regressions;
- client snapshot ordering and heating commands;
- exact The Ark climate option mapping and curve endpoints/peak;
- bounded heat-source creation, update, deduplication and removal;
- atomic exact-region temperature publication and fallback behavior;
- Java region lookup, overlap precedence, replacement and clearing;
- external-package access to the method invoked by transformed game bytecode;
- optional client module snapshot, disconnect and main-menu cleanup lifecycle;
- optional server module initialization, minute refresh and complete region
  publication;
- reconnect-stable main/emergency light classification and battery repair;
- Integration import/mirror of Ark heating state.

ZombieBuddy correlation `slice4-heating-20260801-a` validated the live dedicated
server path. A real client command changed the target to 21.5 C. With the
existing exhausted main generator, heating correctly reported `power_shed`.
Starting the backup generator while all loads remained requested was still
insufficient at the current fallout temperature. After the client shed water
and main lighting, the backup carried 6.73 kW, heating was allocated, produced
4.89 kW and created 38 loaded vent heat sources. Removing power deleted all 38
sources. Test changes were cleaned up: the target and room temperatures were
returned to the 21 C migration baseline before normal minute simulation
resumed; backup fuel/condition/coolant/lubricant are 100/90/90/90%, battery
charge is zero, water and main lighting are requested, and the backup is off.

The first clean 0.8.1 Java test exposed a fatal access error. Both server and
client loaded the integrated patch, but transformed ClimateManager bytecode
could not call the package-private `ThermalOverride.resolve` method. The client
exited at frame 2536 from the cold-moodle path; the server game thread exited at
frame 8 immediately after player creation. That server exit left ArkMP at
`waiting_for_chunks`, so it could neither finish bunker preparation nor issue
the normal automatic teleport. The apparent teleport failure and the crash on
leaving the spawn building therefore had the same Java root cause.

ThermalJava 0.1.0 made the invoked method public and compiles an access probe
from a different Java package, which would fail compilation if this regression
returned. The mandatory clean dedicated-server and client restart was accepted
with correlation `slice4-thermal-optional-20260801-a`. The dedicated server
correctly skipped the client-only API (`bcThermalResolve == nil`), reached ArkMP
`ready`, and automatically placed `admin` in the infirmary at
9965.86,12622.04,-4. The client loaded the optional API, published 25 exact
thermal regions and applied 5.288 C consistently through character, square and
registry climate lookups. Both ZombieBuddy endpoints remained healthy. That
acceptance covered display paths but exposed a second MP boundary afterward:
the dedicated server had correctly skipped the then-client-only JAR, so its
authoritative BodyDamage simulation still used vanilla indoor temperature.
Clocks showed the real cold while the player could not develop hypothermia.

ThermalJava 0.2.0 moves the unchanged JAR to the two-sided `media/java` path
and adds a replaceable server publisher. Correlation
`slice4-server-thermoreg-20260801-b` accepted the corrected clean restart. Both
processes loaded the Java API and 25 regions without `IllegalAccessError`; the
server's `getAirTemperatureForSquare`, `getAirTemperatureForCharacter`,
`Thermoregulator.getTemperatureAir` and cached external-air value agreed. As
the infirmary fell to 0.106 C, the authoritative core temperature fell to
36.137 C with body heat delta -0.691, and both server and client reported
hypothermia level 1. All three server publisher callbacks were registered
exactly once.

The same clean run validated lighting after reconnect. The client received all
847 manifest entries and completed reconciliation. Its loaded world contained
193 main and 653 emergency matches; main was requested on, emergency was
requested off, and neither class had any activation mismatch. ArkMP server and
client callbacks, plus every optional ThermalJava lifecycle callback, each had
exactly one registration. No `IllegalAccessError` recurred. Early bunker object
streaming still logs transient `ObjectChangePacket` index misses while the
client receives the dynamically built structure, but they stop after loading;
the manifest reconciliation is what establishes the final correct client
lighting state.

To test the detachable fallback, disable only `BunkerCampaignThermalJava` on
both server and client and restart both processes; all other campaign mods must
still load and the only expected regression is vanilla +22 C indoor reporting
and thermoregulation. That disabled-module restart has not yet been exercised
because it would interrupt the currently accepted enabled-module runtime.

### Physical heating, failures and repair completion pass (2026-08-01)

Core 0.7.0 completes the gameplay layer that was still missing from the fourth
slice. It reuses six existing Ark objects rather than creating replacement
furniture:

- controller: `9963,12627,-4`, `appliances_com_01_52`;
- heat exchanger: `9968,12633,-4`, `industry_02_17`;
- circulation blower: `9967,12635,-4`, `rooftop_furniture_5`;
- supply valve: `9966,12637,-4`, `industry_02_55`;
- return valve: `9966,12639,-4`, `industry_02_62`;
- pipe manifold: `9966,12640,-4`, `industry_02_16`.

The Bunker Systems context option now exists only on the physical controller.
Heating enable, target and room-circuit mutations are also validated against
controller distance and controller health on the server, so a forged client
command cannot operate heating remotely. Every component interaction validates
the exact coordinate, sprite and player distance on the server.

Normal heat distribution now requires allocated heating power, a serviceable
controller, exchanger, pipe circuit and circulation blower, both supply and
return valves open, and an actually operating ventilation mode with nonzero
airflow. `off`, `sealed`, power-shed ventilation, a stopped fan, a closed valve
or a seized blower therefore stops normal distribution. A physical action at
the exchanger can enable a manual emergency bypass; it preserves only 25% of
normal distribution and does not remove the power, exchanger or pipe-circuit
requirements.

Persistent component condition, pipe integrity, valve position, diagnosis,
temporary-repair state and accident counters are introduced by state migration
7 -> 8. Operating equipment wears gradually; temporary repairs wear four times
faster. Extreme cold can also damage an unheated pipe manifold. Automatic
incidents are bounded to two active failures, at most one major failure, and a
six-game-hour global cooldown. Faults have local consequences: controller and
major exchanger/circuit faults stop the relevant path, fouling/leaks/bearing
wear reduce output, seized circulation and stuck-closed valves stop normal
distribution, and stuck-open valves cannot be isolated. Administrator-only
minor/major fault actions remain available for scenario and QA setup.

Right-clicking an exact component now exposes diagnosis, temporary repair and
full repair timed actions with English requirement tooltips. The server checks
Electricity, Mechanics and MetalWelding as appropriate, requires the matching
tools, consumes only validated vanilla replacement parts, awards small skill
XP and broadcasts the authoritative result. Temporary repairs use Duct Tape,
Wire/Scrap Metal and lower skill thresholds; full repairs use combinations of
Screwdriver, Wrench, Blow Torch, Welding Mask, Electronics Scrap, Electric
Wire, Iron Pipe and Sheet Metal. A full repair is deliberately capped below
perfect condition, while a temporary repair only restores an emergency service
level.

Automated tests cover ventilation/circulation/valve dependency, reduced manual
bypass output, legacy exchanger/pipe compatibility, natural and forced failure
bounds, cooldown, diagnosis, temporary repair, full server-side skilled repair,
part consumption and all earlier core regressions. Every Core Lua file passes
the Build 42 Kahlua compiler.

ZombieBuddy correlations `slice4-heating-control-20260801` and
`slice4-heating-valve-20260801` exercised real client -> dedicated server ->
client paths. A target change from the old arbitrary bunker position was
rejected with `heating_controller_required`; the same command beside the Ark
controller changed and replicated the target. The physical supply valve closed
and reopened only from its own tile, and the exchanger manual bypass enabled
and disabled only from the exchanger. All target, valve, bypass and player
position changes were restored. A physical audit found all six reused objects
loaded with their expected sprites. After correlation
`slice4-heating-final-20260801`, neither process logged a new error.

The live runtime was initially hot-loaded for MP validation, but the two newly
added Lua files were not in the startup-time require catalogue and produced
expected hot-reload-only `require failed` warnings before they were loaded by
absolute path. The user then performed the required clean dedicated-server and
client restart. Core state version 8, all six physical component states and the
new client timed-action file loaded normally; no startup `require failed`
warning remained. The optional Java thermal module remains fully separate and
unchanged.

### Shared heating QA tools and post-restart validation (2026-08-01)

Commit `05ac9a9` extends the existing administrator-only
`Bunker Campaign: QA tools` context menu instead of creating a separate debug
UI. `Travel and resources` now includes the bunker arrival point, all six
physical heating components and the existing ArkMP service/deep-level
inspection commands. `Heating system` provides deterministic room-temperature
presets, a cold powered test state, generator power-shed, ventilation-off and
recirculation states, manual bypass, both valves, restore-all and per-component
healthy/minor/major states. All labels are English.

Every heating QA mutation is validated as administrator-only and applied by the
authoritative core server. The cold powered state restores components to 90%,
enables every room circuit, sets rooms to 5 C and target to 21 C, supplies the
main generator, releases the water/main-lighting loads and starts internal
recirculation. Per-component fault setters deliberately bypass the random
incident concurrency/cooldown caps so QA can build exact multi-failure states;
they still use the real component fault values and failure consequences.

Automated server regressions verify ordinary-client rejection, deterministic
cold-state setup, the ventilation dependency, exact simultaneous major faults,
restore-all and heating-component teleport coordinates. The focused core and
decontamination server suites pass, and every changed Lua file passes the Build
42 Kahlua compiler.

ZombieBuddy correlation `slice4-heating-qa-001` exercised the real client ->
server -> client path after the clean restart. The server and client agreed on
the same state revision for a 5 C cold start with operating heat. Separate
commands produced `air_circuit_unavailable`, `power_shed`,
`controller_failed` and `pipe_circuit_failed` for the corresponding physical
scenarios. Closing the supply valve stopped distribution, two diagnosed major
faults could be installed simultaneously, and the common QA teleport moved the
player to the pipe manifold and back to the arrival point. The authoritative
state and player position were restored afterward: no active heating failures,
the pre-test power/heating state, and `9966,12622,-4`.

Two errors after the first correlation marker came only from malformed
read-only ZombieBuddy event-inspection snippets (`Expected a table` against the
v3 event-list userdata). No gameplay callback or mod code appears in those
stacks. The actual MP scenarios completed normally.

The user then performed the requested clean restart. Correlation
`slice4-heating-qa-clean-start` confirmed that CampaignState, ServerCommands,
DecontaminationServer and DecontaminationClient all loaded from the expected
local paths. Core state version 8 matched at revision 45 on server and client.
Every relevant server and client callback was registered exactly once. A real
ISContextMenu construction found the complete shared QA hierarchy, including
all heating state controls, all six component submenus and all travel targets.
No Bunker Campaign `require failed`, `IllegalAccessError`, Lua exception or
stack trace appeared during startup or the clean-start network scenario.

The clean run also exercised the natural accident path without a QA setter. At
world age 10.4002 the server generated an undiagnosed controller
`sensor_drift`, incremented the persistent accident counters and degraded heat
output. A later QA minor-fault round trip was restored to its exact pre-test
snapshot, so this natural fault remains in the save intentionally and is ready
for physical diagnosis/repair testing at the controller.

Commit `cc1532d` adds the last manual-test conveniences to `Heating system`:
an administrator-only server command issues enough tools, full-repair parts and
temporary-repair materials to exercise every component, while a clearly named
client action uses the vanilla admin XP synchronization path to set
Electricity, Mechanics and MetalWelding to level 10. All eleven referenced
vanilla item scripts were present in the live Build 42.19 server. Automated
tests verify ordinary-client rejection, item creation and per-item container
synchronization. The two actions were hot-loaded and appeared in the real menu;
they were not executed against the live character, avoiding unwanted inventory
or permanent skill changes. One final restart is needed only to confirm these
two convenience actions from startup.

Fourth-slice commits so far:

- `e08672b` - server-authoritative bunker heating core;
- `4b2216b` - MP adaptation of The Ark climate and heating;
- `57e4c36` - authoritative room temperature exposed to vanilla climate;
- `1c8ae70` - reconnect-stable emergency light identity and reconciliation;
- `bc68dce` - local ZombieBuddy runtime marker and dependency setup;
- `6657a0f` - isolate the optional Java bridge and repair external access;
- `82bee8d` - publish optional room climate to MP server thermoregulation;
- `f022e4b` - physical heating components, dependencies, failures and repair;
- `5be6a11` - document the completed physical heating gameplay layer;
- `05ac9a9` - authoritative shared heating QA scenarios and travel controls;
- `83cd42f` - record clean-start QA validation procedure;
- `cc1532d` - complete heating repair kit and skill QA setup;
- `b4ea265` - record clean-start heating QA acceptance.

## Build 42.20 compatibility audit (2026-08-01)

The live game was verified as Project Zomboid 42.20.0 (`a2947723ca`, Steam
build 24449119). The current Workshop sources were compared with their previous
versions before changing local forks. In particular, The Ark 42.20 removed the
client-side `transmitCompleteItemToServer()` calls from `BWOABuildTools.lua`
and changed light removal to the new transmitted object-removal path. Bandits
42.20 replaced two `becomeCorpseSilently()` calls with `die()`. The local forks
did not contain the obsolete Bandits corpse API; ArkMP's remaining obsolete
complete-item client call was removed.

Build 42.20 introduced a fatal Windows dedicated-server regression in
`AdvancedAnimator.loadModMedia`: the engine lowercases a canonical mod URI
before a case-sensitive `URI.relativize`, then passes the resulting absolute
lowercase path to the virtual filesystem. A clean server consequently failed
while checksumming Bandits animation files before Lua startup.
`BunkerCampaignBuild42Compat` 0.1.0 is the narrowly scoped required Java patch.
It instruments `ZomboidFileSystem.getRelativeFile(URI, String)` and substitutes
a canonical, case-insensitive Windows-relative path only when vanilla returned
the unchanged absolute input. The patch unit test passes, and live logs confirm
that it loads before checksum collection and permits the server to reach
`*** SERVER STARTED ****`. Keep it before ArkMP in `default.txt`; ArkMP also
declares it as a requirement.

Build 42.20 also initializes `GlobalModData` before `GameServer.udpEngine`.
`CampaignState` now defers network publication until `OnServerStarted` while
preserving pending changes. Its server regression deliberately makes
`getOnlinePlayers()` throw before that event and confirms that initialization
sends no packet; publication resumes after the event. This removes the Bunker
Campaign startup exception. Generic `udpEngine is null` messages can still be
emitted by Bandits/other dependencies during the same upstream lifecycle.

Automated acceptance against the 42.20 game JAR:

- all 126 existing local-fork Lua files pass the Build 42 Kahlua compiler;
- all focused Core, ArkMP, ToxicMP and Integration Lua suites pass, including
  power, ventilation, life support, heating, water, decontamination, client and
  server entry coverage;
- both optional thermal Java compilation/access tests and
  `ThermalOverrideTest` pass against 42.20;
- the compatibility patch compiles against 42.20 and its Windows-path unit test
  passes;
- a clean dedicated server loads all campaign server modules, migrates state to
  version 8, activates the thermal bridge and reaches `SERVER STARTED` with
  power and heating operational.

The separate ZombieBuddy client role loaded all campaign client modules,
received server options and player data, and completed the 42.20 world-loading
sequence. A full server-to-client campaign-snapshot acceptance could not be
completed under the current ZombieBuddy experimental native agent: after
`CreatePlayerPacket.processServer`, the client retains a player without a
current square and the server keeps zero online players. The same result occurs
through the vanilla saved-account `MultiplayerUI`, so it is not the earlier
low-level login shortcut. At connection time ZombieBuddy reports missing
experimental packet-cache handlers, including `ClientCommand`. Treat the
Build 42.19 real C -> S -> C acceptance above as the last completed gameplay
baseline and perform one ordinary, non-instrumented manual client connection on
42.20 before declaring the runtime network path fully re-accepted.

Build 42.20 currently logs noisy non-fatal upstream errors while scanning
missing optional `media/AnimSets` and `media/actiongroups` directories for many
mods. The same clean run also retains vanilla/map-data warnings for mannequin
properties, duplicate basement room meta IDs, missing sprite configurations
and icons. These warnings did not prevent server startup and are not evidence
of a Bunker Campaign callback failure.
