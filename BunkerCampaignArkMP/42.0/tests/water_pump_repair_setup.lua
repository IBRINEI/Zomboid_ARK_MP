BunkerCampaignArkMP = BunkerCampaignArkMP or {}
BWOARooms = {}
BunkerCampaign = {
    CampaignState = { addPowerListener = function() end },
}
BunkerCampaignArkMP.PowerGrid = {
    sync = function() return true end,
    setNetworkReady = function() end,
    buildExpectedEmergencyLights = function() return {} end,
    getLightingState = function() return {mainActive=true, emergencyActive=false} end,
}

local function event()
    local result = { handlers = {} }
    result.Add = function(handler) result.handlers[#result.handlers + 1] = handler end
    result.Remove = function(handler)
        for index = #result.handlers, 1, -1 do
            if result.handlers[index] == handler then table.remove(result.handlers, index) end
        end
    end
    return result
end

Events = {
    OnInitGlobalModData = event(),
    OnServerStarted = event(),
    EveryOneMinute = event(),
    OnClientCommand = event(),
    LoadGridsquare = event(),
}

isClient = function() return false end
isServer = function() return true end

local square = {
    getChunk = function() return {} end,
}
local cell = {
    getGridSquare = function(self, x, y, z)
        if x == 9950 and y == 12616 and z == -4 then return square end
        return nil
    end,
}
getCell = function() return cell end

WPIso = {
    GetPump = function(target) return target.pump end,
}
local repairCalls = 0
BWOABuildTools = {
    WaterPump = function(x, y, z)
        repairCalls = repairCalls + 1
        square.pump = { x = x, y = y, z = z }
        return square.pump
    end,
}

ModData = {
    getOrCreate = function() return {} end,
    transmit = function() end,
}
sendServerCommand = function() end
getGameTime = function() return { getWorldAgeHours = function() return 0 end } end

function ArkMPWaterPumpRepairCalls() return repairCalls end
function ArkMPWaterPumpRepairSquare() return square end
