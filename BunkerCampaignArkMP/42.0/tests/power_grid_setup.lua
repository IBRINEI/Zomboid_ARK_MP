BunkerCampaignArkMP = {
    Constants = {
        NETWORK_MODULE = "BunkerCampaignArkMP",
        GRID_GENERATORS = {},
        LIGHT_SCAN = { x1=0, x2=1, y1=0, y2=0, levels={ -4 } },
    },
}

local function light(useBattery)
    return {
        className = "IsoLightSwitch",
        active = false,
        useBattery = useBattery,
        getObjectIndex = function() return 0 end,
        getUseBattery = function(self) return self.useBattery end,
        isActivated = function(self) return self.active end,
        setActive = function(self, active) self.active = active end,
        syncIsoObject = function() end,
    }
end

local mainLight = light(false)
local emergencyLight = light(true)
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

BWOARooms = { Control={ els={ {x=1, y=0, z=-4} } } }
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
