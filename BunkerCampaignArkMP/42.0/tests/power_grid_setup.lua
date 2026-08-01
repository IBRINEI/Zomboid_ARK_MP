BunkerCampaignArkMP = {
    Constants = {
        NETWORK_MODULE = "BunkerCampaignArkMP",
        GRID_GENERATORS = {},
        LIGHT_SCAN = { x1=0, x2=1, y1=0, y2=0, levels={ -4 } },
    },
}

local function light(useBattery, spriteName)
    return {
        className = "IsoLightSwitch",
        active = false,
        useBattery = useBattery,
        hasBattery = useBattery,
        canBeModified = true,
        getObjectIndex = function() return 0 end,
        getUseBattery = function(self) return self.useBattery end,
        getHasBattery = function(self) return self.hasBattery end,
        getCanBeModified = function(self) return self.canBeModified end,
        getSprite = function()
            return { getName=function() return spriteName end }
        end,
        isActivated = function(self) return self.active end,
        setActive = function(self, active) self.active = active end,
        setCanBeModified = function(self, value) self.canBeModified = value end,
        setPower = function(self, value) self.power = value end,
        setHasBattery = function(self, value) self.hasBattery = value end,
        setUseBatteryDirect = function(self, value) self.useBattery = value end,
        syncIsoObject = function() end,
    }
end

local mainLight = light(false, "lighting_outdoor_01_40")
-- Saved/streamed B42 switches lose useBattery.  Coordinate + expected sprite
-- must still preserve this fixture's emergency role after a reconnect.
local emergencyLight = light(false, "location_entertainment_theatre_01_138")
local function objectsFor(object)
    return {
        size = function() return 1 end,
        get = function(self, index) if index == 0 then return object end end,
    }
end
local squares = {
    ["0:0:-4"] = { getChunk=function() return {} end, getObjects=function() return objectsFor(mainLight) end },
    ["1:0:-4"] = { getChunk=function() return {} end, getObjects=function() return objectsFor(emergencyLight) end },
}

getCell = function()
    return {
        getGridSquare = function(self, x, y, z) return squares[tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)] end,
    }
end
instanceof = function(object, className) return object and object.className == className end
isClient = function() return false end
isServer = function() return true end

BWOARooms = { Control={ els={ {dir="N", x=1, y=0, z=-4} } } }
local power = {
    gridOnline = true,
    emergencyMode = false,
    consumers = {
        main_lighting = { allocated=true },
        emergency_lighting = { allocated=false },
    },
}
BunkerCampaign = { CampaignState={ get=function() return { bunker={ modules={ power=power } } } end } }

local commands = {}
sendServerCommand = function(module, command, args)
    commands[#commands + 1] = { module=module, command=command, args=args }
end

function ArkMPPowerGridState() return power end
function ArkMPPowerGridLights() return mainLight, emergencyLight end
function ArkMPPowerGridCommands() return commands end
