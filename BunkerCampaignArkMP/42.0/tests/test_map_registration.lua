local handlers = ArkMPMapHandlers()
assert(#handlers == 1, "map registration must subscribe to OnLoadMapZones")
assert(handlers[1](), "map registration must succeed")

local recorded = ArkMPMapRecorded()
assert(recorded.mapID == "Muldraugh, KY", "basement definitions must target the active vanilla map")
assert(recorded.spawnMapID == "Muldraugh, KY", "spawn locations must target the active vanilla map")
assert(type(recorded.definitions.ark_underground_all) == "table", "main Ark prefab must be registered")
assert(type(recorded.definitions.ark_twinrooms) == "table", "supplementary rooms must be registered")
assert(#recorded.locations == 2, "only the two Ark bunker prefabs must be spawned")
assert(recorded.locations[1].x == 9948 and recorded.locations[1].z == -4, "main prefab origin must be preserved")

print("BunkerCampaignArkMP map registration tests passed")
