BunkerCampaignArkMP = {}
BWOARooms = {}
local roomMetadataInitCalls = 0
BWOARooms.Control = {
    Init = function()
        roomMetadataInitCalls = roomMetadataInitCalls + 1
        BWOARooms.Control.els = { { x=9960, y=12622, z=-4 } }
    end,
}
BunkerCampaign = {
    CampaignState = {
        addPowerListener = function(listener) end,
    },
}
local powerSyncCalls = 0
BunkerCampaignArkMP.PowerGrid = {
    sync = function()
        powerSyncCalls = powerSyncCalls + 1
        return true
    end,
    getLightingState = function()
        return { mainActive=true, emergencyActive=false }
    end,
    setNetworkReady = function() end,
}

local function event()
    local result = { handlers = {} }
    result.Add = function(handler) result.handlers[#result.handlers + 1] = handler end
    return result
end

Events = {
    OnInitGlobalModData = event(),
    OnServerStarted = event(),
    OnReceiveGlobalModData = event(),
    EveryOneMinute = event(),
    OnClientCommand = event(),
    LoadGridsquare = event(),
}

local modData = {}
local serverCommands = {}
local transmitted = {}
local characterData = {}
local player = {
    x = 10944,
    y = 9374,
    z = 0,
    username = "normal-player",
    getUsername = function(self) return self.username end,
    getX = function(self) return self.x end,
    getY = function(self) return self.y end,
    getZ = function(self) return self.z end,
    teleportTo = function(self, x, y, z)
        self.x, self.y, self.z = x, y, z
        self.serverTeleported = true
    end,
    getNetworkCharacterAI = function(self)
        self.networkAIRequested = true
        return {
            resetSpeedLimiter = function() self.speedLimiterReset = true end,
            resetState = function() self.networkStateReset = true end,
        }
    end,
    isAccessLevel = function(self, level) return level == "admin" and self.admin == true end,
    getModData = function() return characterData end,
    transmitModData = function(self) self.modDataTransmitted = true end,
}

GameServer = {
    sendTeleport = function(target, x, y, z)
        target.x, target.y, target.z = x, y, z
        target.serverTeleported = true
        target.nativeTeleported = true
    end,
}

isClient = function() return false end
isServer = function() return true end
getCell = function()
    return {
        getGridSquare = function(self, x, y, z)
            return {
                getChunk = function() return {} end,
                getObjects = function()
                    return { size=function() return 0 end, get=function() return nil end }
                end,
            }
        end,
    }
end
instanceof = function(object, className) return false end
getGameTime = function()
    return { getWorldAgeHours = function() return 12 end }
end
ModData = {
    getOrCreate = function(key)
        modData[key] = modData[key] or {}
        return modData[key]
    end,
    transmit = function(key) transmitted[#transmitted + 1] = key end,
    request = function(key) end,
}
sendServerCommand = function(target, module, command, args)
    serverCommands[#serverCommands + 1] = {
        target = target,
        module = module,
        command = command,
        args = args,
    }
end

function ArkMPServerEntryPlayer() return player end
function ArkMPServerEntryCommands() return serverCommands end
function ArkMPPowerSyncCalls() return powerSyncCalls end
function ArkMPRoomMetadataInitCalls() return roomMetadataInitCalls end
function ArkMPCharacterData() return characterData end
