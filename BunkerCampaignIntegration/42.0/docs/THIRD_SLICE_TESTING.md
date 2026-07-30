# Third-slice dedicated MP test: water and ventilation

Target: Project Zomboid 42.19. Test with one administrator and at least one
ordinary client. Back up the server save before the first run.

## Required mod set

Enable the accepted local forks and dependencies:

- `Bandits2`;
- `Waterpipes`;
- `BunkerCampaign` 0.5.0;
- `BunkerCampaignArkMP` 0.4.5 or the current accepted build;
- `BunkerCampaignToxicMP` 0.5.0;
- `BunkerCampaignIntegration` 0.7.0.

Keep the original The Ark, original Toxic Zones, Bandits Day One/Week One and
Cryogenic Winter disabled.

The server log should report integration initialization and a non-zero room
count. It must not produce an error every tick or register two independent
life-support minute loops.

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
   and only bounded leakage/mixing remains.
6. Walk through the bunker and compare the panel's worst-room value while the
   two clients move between rooms.

Expected: room occupancy follows actual player coordinates. A newly declared
garage or laboratory appears without adding its name to simulation code.

## 4. Intake contamination and filter bank

1. With administrator QA actions, create an exterior toxic zone over one or
   more Ark intake tiles.
2. Run external filtration and observe intake contamination, filtered internal
   contamination and filter percentage.
3. Confirm the filter drains only in proportion to contaminated airflow.
4. Switch to recirculation or sealed mode and confirm exterior filter loading
   stops or falls to the appropriate bounded behavior.
5. Let the filter approach exhaustion, or enable treatment bypass only for the
   separate water test below. Verify airborne contamination enters affected
   rooms after ventilation protection is lost.
6. Confirm ToxicMP increases player exposure inside contaminated rooms and a
   worn functioning gas mask reduces that exposure while consuming its own
   mask filter.
7. Carry one `Base.GasmaskFilter`, use `Replace vent filter`, and verify exactly
   one inventory filter is consumed. If the removed bunker filter still had
   charge, verify it is returned as a used filter rather than becoming full.

Expected: ToxicMP, not the ventilation simulation, owns player exposure and
mask consumption. Runtime strings are English.

## 5. Airlock purge

1. Start an airlock purge while ventilation power and a usable filter are
   available.
2. Remove power during the purge, wait, then restore power.
3. Repeat once with all intakes unavailable or broken.
4. Reconnect one client and restart the server during a separate purge.

Expected: the deadline pauses when prerequisites are lost, resumes safely and
completes once. It does not duplicate resource use or lose its persistent
state.

## 6. Water sources, pump and treatment

1. Inspect the physical Waterpipes pump, connected storage and installed
   filter. Request the bunker water pump.
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
