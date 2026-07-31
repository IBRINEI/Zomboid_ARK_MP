# Third-slice dedicated MP test: water and ventilation

Target: Project Zomboid 42.19. Test with one administrator and at least one
ordinary client. Back up the server save before the first run.

## Required mod set

Enable the accepted local forks and dependencies:

- `Bandits2`;
- `Waterpipes`;
- `BunkerCampaign` 0.5.2;
- `BunkerCampaignArkMP` 0.4.5.1 (the stable 0.4.5 lighting code plus QA-menu cleanup);
- `BunkerCampaignToxicMP` 0.5.1;
- `BunkerCampaignIntegration` 0.7.3.

Keep the original The Ark, original Toxic Zones, Bandits Day One/Week One and
Cryogenic Winter disabled.

The server log should report integration initialization and a non-zero room
count. It must not produce an error every tick or register two independent
life-support minute loops.

## Administrator QA menu

Right-click any world tile and open `Bunker Campaign: QA tools`.

`Atmosphere and airlock` provides a single-Z 11x11 toxic zone centered on the
selected tile, a dedicated zone over all surface air intakes, room CO2 and
airborne-contamination setters, ventilation-filter setters, purge completion,
per-intake break/repair actions and a persistent scrollable server report. QA zone changes reach ventilation immediately;
no separate refresh command is required.

`Water system` can fill the real bunker Waterpipes storage with clean or
tainted water, empty it, damage/repair the physical pump, set its real
treatment filter, add/select a finite external source and open a persistent
water-only report. The clean/tainted/empty actions mutate loaded physical
sinks and containers immediately, not only Waterpipes' pending transfer
buffers. These controls exist only to create known test states quickly.

The physical installation being tested consists of the Ark water-pump object
at `9950,12616,-4`, its Waterpipes record, the short pipe run and flowmeter,
and every Waterpipes barrel/receiver discovered inside bunker bounds. The
campaign panel does not create a second invisible tank: its clean/tainted and
capacity values are a view of those physical Waterpipes containers.

Right-clicking the physical pump tile also exposes `Bunker Campaign: Enable
physical water pump` or `Disable physical water pump`. This changes the same
campaign request as the systems panel; the next power-allocation phase decides
whether the pump can actually operate.

## 1. Save migration and access

1. Start the existing accepted save, join as administrator, then join as an
   ordinary player.
2. Confirm both players spawn/teleport normally and can reopen the bunker
   systems panel after reconnecting.
3. Confirm an ordinary player inside the bunker can operate ventilation and
   water controls. Confirm a player outside the bunker is rejected.
4. Restart the dedicated server and confirm mode, filter state, source state,
   room contamination, clean/tainted storage and active airlock purge persist.

Expected: old saves migrate once to state version 6; no character-creation or
main-menu Ark UI appears.

## 2. Electrical dependency

1. Request external filtration and the water pump.
2. Verify the systems panel shows requested and operating states separately.
3. Remove bunker generation/available power while leaving ordinary map lights
   in any state.
4. Verify the Waterpipes pump physically stops, water flow becomes zero and
   powered ventilation airflow becomes zero.
5. Restore bunker power.

Expected: both systems resume only after the power allocator grants their
loads. A lit tile is not proof of bunker-system power.

## 3. Ventilation modes and rooms

Run these checks with both clients inside, preferably in different rooms.

1. Select `Off`: airflow should become zero and occupied-room CO2 should rise.
2. Select `Internal recirculation`: room air should mix, but total occupant CO2
   must not disappear as if outside air had been introduced.
3. Select `External filtration`: usable intakes should exchange filtered air,
   reducing CO2 toward the outside baseline.
4. Select `Emergency ventilation`: requested load and airflow should exceed
   normal external filtration.
5. Select `Sealed`: outside intake flow should stop; occupied-room CO2 rises
   but there is no intentional outside leakage. Select `Off` again to verify
   passive room leakage remains the meaningful distinction.
6. Walk through the bunker and compare the panel's worst-room value while the
   two clients move between rooms.
7. Open `Room CO2 map and mode help`. Confirm the corridor and every bounded
   Ark room appear with their individual CO2, airborne contamination,
   occupants, airflow and inferred connections.

Expected: room occupancy follows actual player coordinates. A newly declared
garage or laboratory appears without adding its name to simulation code.

## 4. Intake contamination and filter bank

1. Use `Create toxic zone over all air intakes (Z=0)` in the administrator QA
   menu.
2. Run external filtration and observe intake contamination, filtered internal
   contamination and filter percentage.
3. Confirm the filter drains only in proportion to contaminant actually
   captured. With clean intakes it intentionally stays fixed; the panel/report
   says `idle_intakes_clean`. A serviceable filter blocks intake contamination
   completely until it is exhausted or fails.
4. Switch to recirculation. It does not remove CO2, but it cleans existing
   airborne contamination; filter use and `recirc removal` remain zero once
   internal air is clean. Sealed mode stops both the fan and filter loading.
5. Let the filter approach exhaustion, or enable treatment bypass only for the
   separate water test below. Verify airborne contamination enters affected
   rooms after ventilation protection is lost.
6. Confirm ToxicMP increases player exposure inside contaminated rooms and a
   worn functioning gas mask reduces that exposure while consuming the same
   vanilla drainable `Base.GasmaskFilter` resource used by bunker ventilation.
7. Carry one `Base.GasmaskFilter`, use `Replace vent filter`, and verify exactly
   one inventory filter is consumed. If the removed bunker filter still had
   charge, verify its native `Remaining` value is preserved instead of becoming
   full. Insert and remove the same item type from a mask and confirm that charge
   is transferred through `Remaining`, without a second Condition-based meter.

Expected: ToxicMP, not the ventilation simulation, owns player exposure and
mask consumption. Runtime strings are English.

## 5. Airlock purge

The entry report tracks four gates: the surface gate at `9926,12625,0`, then
the three bunker gates at `9924`, `9934` and `9944`, all at `y=12625,z=-4`.
All four must be loaded and open before the path reports `BREACHED`.

1. Start an airlock purge while ventilation power and a usable filter are
   available.
2. Remove power during the purge, wait, then restore power.
3. Repeat once with all intakes unavailable or broken.
4. Reconnect one client and restart the server during a separate purge.

Expected: the deadline pauses when prerequisites are lost, resumes safely and
completes once. It does not duplicate resource use or lose its persistent
state.

## 6. Water sources, pump and treatment

Fast administrator pass from `Bunker Campaign: QA tools` -> `Water system`:

1. Select `Fill bunker storage with clean water`, `Repair physical pump to
   100%`, `Set Waterpipes treatment filter to 100%`, then `Request bunker water
   pump ON` and `Report physical water state`. Expect an operational pump,
   clean storage and non-zero flow when bunker power is allocated.
2. Right-click the physical pump tile and use `Bunker Campaign: Disable
   physical water pump`. Report again and expect both the campaign request and
   physical pump to be off. Re-enable it from the same tile.
3. Select `Set physical pump condition to 25%`, then repair it to 100%; the
   report and Waterpipes UI must agree after each action.
4. Select `Fill bunker storage with tainted water`, set the treatment filter to
   10%, then restore it to 100%. This isolates storage quality and treatment
   state without waiting for normal consumption.
5. Select `Empty bunker water storage`, then `Add and select 100 L external
   tainted supply` to test a finite source. Request the pump and confirm actual
   produced liters reduce the external supply rather than creating water.
6. Fill storage with tainted water and immediately draw from a registered
   sink. The sink must supply tainted water. Use `EMPTY ALL bunker water
   storage` (the action also stops the pump), then verify the same
   sink/receiver has no water and the report remains open long enough to read.

The four surface air-intake objects are at `9940..9941,12633..12634,0`. Use
`[QA] Surface air intakes`, right-click the exact intake tile, and choose the
break or repair action. The room-status window and atmosphere report list each
intake independently so partial capacity and failover can be verified.

The bunker water system consists of the physical Waterpipes pump, its connected
pipes/flowmeter and Waterpipes storage barrels, plus the campaign power request,
selected source and treatment/bypass state. The campaign panel is a server-owned
summary; it is not a second independent pump.

1. Inspect the physical Waterpipes pump, connected storage and installed
   filter. Request the bunker water pump.
   Use `Report physical water state` if the physical Waterpipes values are not
   obvious from its own context UI.
2. Confirm stored volume and water type in Waterpipes match the campaign panel.
3. With a valid source, pump condition and allocated power, verify flow and
   storage growth. With any one prerequisite removed, verify physical pumping
   stops and the reason changes appropriately.
4. Introduce tainted/contaminated water. With treatment enabled, verify clean
   storage increases according to filter efficiency and treatment condition.
5. Enable treatment bypass. Verify the real Waterpipes filter is removed from
   the active slot without being destroyed, output is classified tainted, and
   disabling bypass restores the same filter state.
6. Exercise a finite external source. Verify only actual pumped liters are
   debited and the source eventually reports depleted.
7. Restart the server and confirm source, clean/tainted storage, bypass and
   physical filter state remain consistent.

## 7. Atomic consumer regression

1. Prepare exactly enough clean bunker water for one decontamination cycle.
2. Have two clients attempt a water-consuming completion at nearly the same
   time.
3. Repeat one completion packet/transaction id if the QA harness permits it.
4. Disconnect and reconnect the initiating client around another completion.

Expected: each unique transaction debits once; the duplicate is idempotently
accepted without a second debit; a competing operation fails cleanly when
water is insufficient. No negative storage is possible.

## 8. Extension smoke test

For a temporary development build, add one rectangular `BWOARooms.Garage` or
explicit `CampaignState.registerRoom` definition with a unique id.

Expected after server restart:

- the initialization room count increases by one;
- entering the bounds changes occupancy for that room;
- the room receives CO2, airflow and contamination state;
- no water, ventilation, ToxicMP or UI source file needs a room-name branch.

## Acceptance record

Record server/client logs and the observed values for all sections. The third
slice is accepted only after the dedicated-server procedure passes and the
user explicitly confirms it. Automated harness success alone is not MP
acceptance.
