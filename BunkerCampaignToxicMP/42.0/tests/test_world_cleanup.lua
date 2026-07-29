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

local ok, cleanedItems, cleanedCorpses = BunkerCampaignToxicMP.Server.cleanWorldInBounds(
    {x1=1,x2=1,y1=1,y2=1,z=0}, 1
)
assert(ok and cleanedItems == 3 and cleanedCorpses == 1,
    "full chamber cleanup must include floor items, nested items and corpse contents")
assert(floorData[key] == 0 and nestedData[key] == 0 and corpseItemData[key] == 0,
    "all world and corpse inventory contamination must be removed")
assert(corpseData[key] == 0 and corpse.transmitted == true,
    "corpse surface state must be cleared and transmitted")

print("BunkerCampaignToxicMP world cleanup tests passed")
