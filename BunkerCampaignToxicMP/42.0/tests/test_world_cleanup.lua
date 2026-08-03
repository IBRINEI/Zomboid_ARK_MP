local key = BunkerCampaignToxicMP.Constants.CONTAMINATION_MODDATA_KEY

local function list(values)
    return {
        size=function() return #values end,
        get=function(self, index) return values[index + 1] end,
    }
end

local function item(value, className, nested)
    local data = { [key]=value }
    return {
        className=className,
        getModData=function() return data end,
        getInventory=function() return nested end,
    }, data
end

local nestedItem, nestedData = item(55, "InventoryItem")
local nestedContainer = { getItems=function() return list({nestedItem}) end }
local floorItem, floorData = item(80, "InventoryContainer", nestedContainer)
local corpseItem, corpseItemData = item(70, "InventoryItem")
local corpseContainer = { getItems=function() return list({corpseItem}) end }
local corpseData = { [key]=90 }
local corpse = {
    className="IsoDeadBody",
    getContainer=function() return corpseContainer end,
    getModData=function() return corpseData end,
    transmitModData=function(self) self.transmitted = true end,
}
local worldObject = {
    className="IsoWorldInventoryObject",
    getItem=function() return floorItem end,
}
local square = {
    getWorldObjects=function() return list({worldObject}) end,
    getStaticMovingObjects=function() return list({corpse}) end,
}

instanceof = function(object, className) return object and object.className == className end
getCell = function()
    return { getGridSquare=function(self, x, y, z) return x == 1 and y == 1 and z == 0 and square or nil end }
end
local invalidOwnerSyncs = 0
syncItemModData = function() invalidOwnerSyncs = invalidOwnerSyncs + 1 end
local cleanupBroadcasts = 0
sendServerCommand = function(player, module, command, args)
    if command == "worldContaminationCleaned" then cleanupBroadcasts = cleanupBroadcasts + 1 end
end

local ok, cleanedItems, cleanedCorpses = BunkerCampaignToxicMP.Server.cleanWorldInBounds(
    {x1=1,x2=1,y1=1,y2=1,z=0}, 0.5
)
assert(ok and cleanedItems == 3 and cleanedCorpses == 1,
    "emergency chamber cleanup must include floor items, nested items and corpse contents")
assert(floorData[key] == 40 and nestedData[key] == 27.5 and corpseItemData[key] == 35,
    "emergency cleanup must remove half of world and corpse inventory contamination")
assert(corpseData[key] == 45 and corpse.transmitted == true,
    "emergency cleanup must partially clean and transmit the corpse surface")

ok, cleanedItems, cleanedCorpses = BunkerCampaignToxicMP.Server.cleanWorldInBounds(
    {x1=1,x2=1,y1=1,y2=1,z=0}, 1
)
assert(ok and cleanedItems == 3 and cleanedCorpses == 1,
    "full chamber cleanup must include floor items, nested items and corpse contents")
assert(floorData[key] == 0 and nestedData[key] == 0 and corpseItemData[key] == 0,
    "full cleanup must remove all world and corpse inventory contamination")
assert(corpseData[key] == 0,
    "full cleanup must remove the remaining corpse surface contamination")
assert(invalidOwnerSyncs == 0,
    "world cleanup must not call player-relative modData synchronization with a nil owner")
assert(cleanupBroadcasts == 2,
    "each world cleanup must tell nearby clients to refresh their local floor and corpse copies")

floorData[key] = 80
floorData.radiated = true
nestedData[key] = 0
corpseItemData[key] = 0
corpseData[key] = 0
local spreadOk, spreadChanged, spreadScanned, sourceMaximum =
    BunkerCampaignToxicMP.Server.spreadWorldContaminationInBounds(
        {x1=1,x2=1,y1=1,y2=1,z=0}, 0, 0.25)
assert(spreadOk and spreadChanged == 3 and spreadScanned == 4 and sourceMaximum == 80,
    "a contaminated nearby item must spread to clean floor, nested and corpse inventory targets")
assert(nestedData[key] == 20 and corpseItemData[key] == 20 and corpseData[key] == 20,
    "world contact must move every nearby surface toward the strongest source")
assert(nestedData.radiated == true and corpseItemData.radiated == true,
    "numeric MP contamination must also maintain The ARK's visual radiated compatibility flag")

print("BunkerCampaignToxicMP world cleanup tests passed")
