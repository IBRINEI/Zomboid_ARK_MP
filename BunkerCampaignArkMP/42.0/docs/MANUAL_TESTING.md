# Multiplayer smoke test

## 0.4.0 power-system slice

This test is valid in an existing 0.3.5 world. Restart the dedicated server and
all clients after updating all three local forks.

1. Enter the bunker with both an administrator and an ordinary player.
2. Open `Bunker: systems status`. The `POWER` section should report the main
   generator as operational, the main grid online, ventilation and water power
   allocated, and a non-zero pump flow after Waterpipes completes a cycle.
3. The ordinary player, while inside the bunker, must be able to use the main
   generator, backup generator, main lighting, ventilation and water buttons.
   The same packets sent by a player outside the bunker must be rejected with
   `bunker_access_required`.
4. Stop the main generator. The main grid, normal lights, ventilation and pump
   must turn off. Red emergency fixtures must turn on, `Emergency battery` must
   begin falling, and Waterpipes must no longer report the pump as powered.
5. Start the backup generator. The main grid, normal lights, ventilation and
   pump must recover; emergency fixtures must turn off.
6. Toggle `Main lighting` while a generator remains online. Only normal bunker
   lights should follow this allocation; ventilation and the pump must continue.
7. Toggle `Water pump`. The physical Waterpipes pump and flow must follow the
   server allocation immediately; `Power allocated` and `Pump` must agree.
8. Restart the server. Generator requests, fuel, condition, coolant, lubricant,
   battery charge and consumer requests must continue from the saved values.

Expected server messages include `physical grid online` or `physical grid
offline`. There must be no repeating `SyncIsoObject` index error, no duplicate
generator objects, and no Waterpipes `no electricity` result while the water
consumer is allocated.

## 0.3.5 missing water-pump recovery

- An existing world is supported; no bunker rebuild is required.
- Restart the server and load the generator room.
- If the physical pump at `9950,12616,-4` is missing, wait one game minute.
- The server must log `restored missing bunker water pump` once.
- The pump must become visible to clients and must not be duplicated on later
  minute ticks or after another restart.

## 0.3.4 light-index recovery

- Fully restart both the dedicated server and every client after updating.
- On an existing test world the server may log `light updater cleanup` once.
  This removes battery-light updaters left detached by the old SP preparation
  code and disables unnecessary ticking for valid decorative battery lights.
- After arrival the server sends a light manifest. The client should log
  `light reconciliation complete` once its basement chunks are loaded.
- Confirm that `NetObject.getObject Can't find object index [-1]` no longer
  repeats once per game minute.

## 0.3.3 dedicated-server recovery

- Restart the server after updating the mod. State version 3 retries the previously failed Generator room once.
- The log may report `removed interrupted Generator objects=N`; this is cleanup of duplicates left by the old every-tick failure.
- Confirm there is no `WPSound.AddToObject` stack trace and construction reaches `bunker construction ready`.
- If a later unrelated build error is fixed without another state-version change, use the admin world-context option `Bunker Campaign: Retry bunker construction`. A failed retry must stop after one attempt instead of spamming every tick.

Use a new disposable world for this test. Version 0.3 registers the Ark binary
basements during map-zone creation. An older save already has its
`map_basements.bin` and cannot be used to verify the corrected structure.

## Enabled mods

1. Bandits (`Bandits2`).
2. Waterpipes.
3. BunkerCampaign.
4. BunkerCampaignArkMP.
5. BunkerCampaignToxicMP.
6. BunkerCampaignIntegration.

Do not enable `TheArk`, `ToxicZonesSTALKERB42`, Bandits Day One/Week One or
Cryogenic Winter.

## Character creation and spawn

1. Host creates a character: only the standard PZ screens should appear.
2. Join with a normal client: The Ark setup screen must not appear there either.
3. Both players should be moved to approximately `9966,12622,-4`.
4. Neither screen may stay faded/black and movement must remain enabled.
5. If automatic entry needs to be repeated, right-click anywhere and select
   `Bunker Campaign: Enter bunker`. This does not require admin rights.
6. The server log should contain, in this order:
   - `[BunkerCampaignArkMP] registered Ark basement prefabs`;
   - `[BunkerCampaignArkMP] entry requested`;
   - `[BunkerCampaignArkMP] arrival confirmed`;
   - `[BunkerCampaignArkMP] all map probes loaded`;
   - `[BunkerCampaignArkMP] bunker construction ready`.

If the server remains waiting, its log now lists the exact missing probes. If
construction reports `build_error` or `prepare_error`, record the complete
`[BunkerCampaignArkMP]` line including room name. Progress is persisted per
room, so preceding rooms are not rebuilt on retry.

## Toxic-zone authority

As an admin, right-click anywhere and select
`Bunker Campaign: Add test toxic zone`.

An unmasked player should receive the overlay and increasing server exposure.
A filtered STALKER mask should stop exposure while its `modData.percent`
decreases. Its tooltip shows the exact English `Filter: N.N%` value, and its
visible condition drops in steps. The same `addZone` command from a normal
player must be rejected. After a radiation death, the replacement character's
first exposure status must be zero.

Remove it through `Bunker Campaign: Remove test toxic zone`. The
server result is shown above the character and written to the client log. No
debug Lua-console command is required.

## Lower levels

The independent `ark_twinrooms` prefab at level -3 is optional and no longer
blocks construction of the main bunker. The required main prefab is checked at
levels -4, -5 and -7. After loading an existing 0.3.1 test world, use `Enter
bunker` once; the server should log `all map probes loaded` and then `bunker
construction ready`.

For geometry inspection, an administrator can use `Bunker Campaign: Inspect
service level (-5)` and `Bunker Campaign: Inspect deep level (-7)`. These are
fixed server-authorized diagnostic teleports and do not start the entry retry
loop.

## Filter recipes

Insert a partially used filter into a supported mask, then remove it. The
returned filter must keep the same remaining percentage; it must not become a
new full filter. The mask tooltip displays an English `Filter: N.N%` bar. Inserting
or removing a filter must work without standing next to a crafting surface.
