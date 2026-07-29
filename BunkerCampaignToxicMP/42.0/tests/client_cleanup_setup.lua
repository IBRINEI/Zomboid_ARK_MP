BunkerCampaignToxicMP = {}

local function event()
    local result = { handlers={} }
    result.Add = function(handler) result.handlers[#result.handlers + 1] = handler end
    return result
end

Events = {
    OnCreatePlayer=event(),
    OnServerCommand=event(),
    OnPlayerUpdate=event(),
    OnPreUIDraw=event(),
}

local function list(values)
    return {
        size=function() return #values end,
        get=function(self, index) return values[index + 1] end,
    }
end

local function item(value, id, className, nested)
    local data = { BunkerCampaignSurfaceContamination=value }
    return {
        className=className or "InventoryItem",
        getID=function() return id end,
        getModData=function() return data end,
        getInventory=function() return nested end,
    }, data
end

local carriedItem, carriedData = item(70, 101)
local inventory = { getItems=function() return list({carriedItem}) end }
local player = { getInventory=function() return inventory end }

local nestedItem, nestedData = item(55, 202)
local nestedContainer = { getItems=function() return list({nestedItem}) end }
local floorItem, floorData = item(80, 201, "InventoryContainer", nestedContainer)
local corpseItem, corpseItemData = item(65, 301)
local corpseContainer = { getItems=function() return list({corpseItem}) end }
local corpseData = { BunkerCampaignSurfaceContamination=90 }
local corpse = {
    className="IsoDeadBody",
    getContainer=function() return corpseContainer end,
    getModData=function() return corpseData end,
}
local worldObject = {
    className="IsoWorldInventoryObject",
    getItem=function() return floorItem end,
}
local square = {
    getWorldObjects=function() return list({worldObject}) end,
    getStaticMovingObjects=function() return list({corpse}) end,
}

getTexture=function() return {} end
getSpecificPlayer=function() return player end
getCell=function()
    return { getGridSquare=function(self, x, y, z)
        return x == 1 and y == 1 and z == 0 and square or nil
    end }
end
instanceof=function(object, className) return object and object.className == className end
isClient=function() return true end

function ClientCleanupCarriedData() return carriedData end
function ClientCleanupFloorData() return floorData end
function ClientCleanupNestedData() return nestedData end
function ClientCleanupCorpseItemData() return corpseItemData end
function ClientCleanupCorpseData() return corpseData end

