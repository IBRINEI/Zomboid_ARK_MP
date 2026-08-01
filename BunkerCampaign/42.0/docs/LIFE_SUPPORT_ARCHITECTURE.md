# Extensible bunker life-support architecture

Target: Project Zomboid 42.19 dedicated multiplayer.

This document describes the third implementation slice. It supersedes the
earlier prototype in which water and ventilation were only top-level boolean
consumers.

## Ownership and tick order

There is one authoritative server tick for life support:

1. discover registered rooms and count occupants;
2. sample ToxicMP intake hazards and the physical Waterpipes network;
3. calculate requested electrical load;
4. let the bunker power system allocate electricity;
5. actuate the Waterpipes pump and ventilation hardware;
6. simulate water quality, storage, room airflow, CO2 and contamination;
7. apply server-owned effects and publish one client snapshot.

This ordering is deliberate. A pump or fan never decides that it is powered
before the electrical system has allocated its load.

State ownership is split as follows:

- `BunkerCampaign` owns persistent life-support state, rooms, power demand and
  the water/air simulation;
- `BunkerCampaignIntegration` discovers Ark rooms, samples real intakes,
  actuates Waterpipes and exposes atomic water transactions;
- `Waterpipes` remains the canonical owner of physical containers, pipe
  topology, installed filters and pump wear;
- `BunkerCampaignToxicMP` remains the sole owner of player exposure and mask
  filter consumption. Internal room contamination is supplied to it by the
  life-support simulation;
- `BunkerCampaignArkMP` supplies bunker geometry and reusable hardware state,
  without restoring the original single-player story controller.

## Adding rooms

The simulations do not contain a list of named rooms. Every room is a record
in `BunkerCampaign.RoomRegistry`. Water and ventilation iterate that registry,
so a garage, laboratory, workshop or later bunker wing does not require a
change to either simulation.

ArkMP rooms with rectangular bounds and a negative Z level are discovered
automatically during integration startup. A future room can therefore be
added to the ArkMP room table in the same form as its existing rooms. The
integration derives a stable snake-case id, volume, vent weight and adjacency.

A separate addon can also register a room explicitly before campaign
initialization:

```lua
BunkerCampaign.CampaignState.registerRoom({
    id = "garage",
    label = "Garage",
    kind = "service",
    bounds = { x1 = 100, y1 = 200, x2 = 112, y2 = 210, z = -2 },
    heightMeters = 3.5,
    ventWeight = 1.6,
    leakRate = 0.004,
    vents = {
        { x = 104, y = 203, z = -2 },
        { x = 110, y = 208, z = -2 },
    },
    connections = { "service_corridor", "airlock" },
})
```

`volumeM3` is optional and is derived from bounds and height. Explicit
connections are recommended for addon rooms; automatic Ark discovery uses
overlapping/touching bounds to infer adjacency. Smaller nested bounds win room
lookup, which permits a chamber to live inside a larger functional area.

Room runtime state is created and migrated automatically. It contains volume,
occupancy, CO2, airborne contamination, airflow, sealing and condition status.

## Ventilation

Supported modes are `off`, `external_filtration`, `internal_recirculation`,
`emergency_ventilation` and `sealed`.

- External filtration exchanges bunker air with all usable outside intakes.
- Recirculation moves air between rooms without pretending to remove CO2.
- Emergency mode requests more power and maximizes outside exchange.
- Sealed mode isolates outside intakes; occupants still generate CO2 and room
  leakage remains bounded.
- Off mode has no powered airflow.

Each intake has its own open/broken/condition/contamination/capacity state.
The shared filter bank has remaining capacity, efficiency, condition, bypass
and fault state. Intake contamination is sampled from ToxicMP. Filter loading
is proportional to actual contaminated airflow, not merely elapsed time.

Airlock purge is a server-owned deadline. It requires allocated ventilation
power and usable filtered airflow, pauses safely when those prerequisites are
lost and resumes without duplicating completion.

Per-room CO2 uses occupant count and physical room volume. High-CO2 gameplay
effects are applied on the server. Internal airborne contamination is passed
to ToxicMP, so masks and filters continue to have one authoritative owner.

## Water

The water system distinguishes request, allocated power, physical availability
and actual operation. Its persistent state contains:

- sources: underground well, external tank, collected water and portable
  supply;
- pump condition, fault and actual operating state;
- treatment filter/condition/bypass/fault;
- clean and tainted storage;
- flow, contamination and transaction telemetry.

Waterpipes owns the actual physical volumes and water types. The integration
adapter samples those values, starts or stops the real pump after power
allocation and temporarily stores/restores the real filter when treatment
bypass is selected.

Other systems must not subtract water directly. They call the server-owned
`WaterService.consume(liters, transactionId, reason)` operation. Transaction
ids are persisted in bounded history, so a repeated client packet, reconnect
or completion callback cannot debit the same operation twice. Decontamination
already uses this service.

Future supply systems can call:

```lua
BunkerCampaign.CampaignState.addWaterSource(
    "external_tank", 250, 0.08, "fuel_truck_delivery"
)
```

The source is then considered by the existing pump/treatment/storage model;
no consumer changes are needed.

## Compatibility rules

- Runtime UI and log strings are English because Cyrillic does not render
  reliably in the target build.
- Existing saves migrate from state version 5 to 6 and retain legacy fields
  for older UI/integration readers.
- No live competing minute event is registered by the integration. Tests may
  call its compatibility update hook directly.
- The original The Ark and Toxic Zones mods must remain disabled; only their
  local MP forks are used.
- Do not restore the removed ArkMP lighting patch while extending this system.
