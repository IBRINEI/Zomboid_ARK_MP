BWOABuildTools = {}
WPSound = nil
WPIso = {
    pumpSprites = { ns = "water-pump" },
    GetPump = function(square) return square.object end,
}

local calls = { complete = 0, added = 0, filter = 0, active = 0, squareChanged = 0, transmitted = 0 }
WPVirtual = {
    PumpAdd = function(x, y, z) calls.added = calls.added + 1 end,
    PumpAddFilter = function(x, y, z) calls.filter = calls.filter + 1 end,
    PumpActivate = function(x, y, z, active) if active then calls.active = calls.active + 1 end end,
}

isServer = function() return true end
isClient = function() return false end
getSprite = function(name) return { name = name } end
WPUtils = { Coords2Id = function(x, y, z) return x .. "-" .. y .. "-" .. z end }
local waterpipes = { Pumps = {} }
GetWPModData = function() return waterpipes end
TransmitWPModData = function() calls.transmitted = calls.transmitted + 1 end

local object = {
    setActivated = function() end,
    setMovedThumpable = function() end,
    createContainersFromSpriteProperties = function() end,
    transmitCompleteItemToClients = function() calls.complete = calls.complete + 1 end,
}
local square = {
    getCell = function() return {} end,
    getChunk = function() return {} end,
    AddSpecialObject = function(self, value) self.object = value end,
    setSquareChanged = function() calls.squareChanged = calls.squareChanged + 1 end,
}
IsoClothingDryer = { new = function() return object end }
getCell = function()
    return { getOrCreateGridSquare = function() return square end }
end

function ArkMPWaterPumpCalls() return calls end
function ArkMPWaterPumpSquare() return square end
function ArkMPWaterPumpState() return waterpipes end
