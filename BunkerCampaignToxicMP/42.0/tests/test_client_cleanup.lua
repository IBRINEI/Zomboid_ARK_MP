local handler = Events.OnServerCommand.handlers[1]
local module = BunkerCampaignToxicMP.Constants.NETWORK_MODULE
local key = BunkerCampaignToxicMP.Constants.CONTAMINATION_MODDATA_KEY

handler(module, "itemContamination", {itemId=101, value=0})
assert(ClientCleanupCarriedData()[key] == 0,
    "an accepted manual wash must immediately refresh the owning client's item modData")

handler(module, "worldContaminationCleaned", {
    x1=1, x2=1, y1=1, y2=1, z=0, removalFraction=0.5,
})
assert(ClientCleanupFloorData()[key] == 40 and ClientCleanupNestedData()[key] == 27.5,
    "emergency cleanup must immediately show partial cleaning of floor and nested items")
assert(ClientCleanupCorpseItemData()[key] == 32.5 and ClientCleanupCorpseData()[key] == 45,
    "emergency cleanup must immediately show partial cleaning of corpse contents and surface")

handler(module, "worldContaminationCleaned", {
    x1=1, x2=1, y1=1, y2=1, z=0, removalFraction=1,
})
assert(ClientCleanupFloorData()[key] == 0 and ClientCleanupNestedData()[key] == 0,
    "world cleanup must refresh floor items and their nested contents")
assert(ClientCleanupCorpseItemData()[key] == 0 and ClientCleanupCorpseData()[key] == 0,
    "world cleanup must refresh corpses and their inventory contents")
assert(ClientCleanupCarriedData().radiated == false
    and ClientCleanupCorpseItemData().radiated == false,
    "client cleanup must clear the legacy radiated flag used by inventory highlighting")

print("BunkerCampaignToxicMP client cleanup tests passed")
