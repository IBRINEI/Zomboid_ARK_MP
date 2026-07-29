local function event()
    local result = { handlers={} }
    result.Add = function(handler) result.handlers[#result.handlers + 1] = handler end
    return result
end

Events = {
    OnInitGlobalModData=event(),
    OnTick=event(),
    OnClientCommand=event(),
}
isClient = function() return false end
isServer = function() return true end

local persisted = {
    ["BunkerCampaign.IntegrationState"] = {},
    WaterPipes = {
        Pumps={ ["9950-12616--4"]={x=9950,y=12616,z=-4,efficiency=100,filter=100,active=true,source="TaintedWater"} },
        Pipes={}, Valves={}, Flowmeters={}, Sprinklers={}, Buildings={},
        Barrels={ bunker={x=9952,y=12603,z=-5,w=3000,wmax=5000,m="Water"} },
    },
}
ModData = {
    getOrCreate=function(key) persisted[key] = persisted[key] or {}; return persisted[key] end,
    transmit=function() end,
}
TransmitWPModData = function() end

local now = 1000
getTimestampMs = function() return now end
local tabletUsed = 0
local tablet = { Use=function() tabletUsed = tabletUsed + 1 end }
local inventory = {
    getFirstTypeRecurse=function(self, itemType)
        if itemType == "Bandits.NBCTablets" and tabletUsed == 0 then return tablet end
        return nil
    end,
    AddItem=function() end,
}
local player = {
    getUsername=function() return "decon-tester" end,
    isAccessLevel=function(self, level) return level == "admin" end,
    getX=function() return 9946 end,
    getY=function() return 12625 end,
    getZ=function() return -4 end,
    getInventory=function() return inventory end,
    isDead=function() return false end,
}
local online = { size=function() return 1 end, get=function() return player end }
getOnlinePlayers = function() return online end
sendServerCommand = function() end

local power = { consumers={ decontamination={requested=false,allocated=false} } }
BunkerCampaign.CampaignState = {
    get=function() return { bunker={modules={power=power}} } end,
    setConsumerRequested=function(id, requested)
        power.consumers[id].requested = requested
        power.consumers[id].allocated = requested
        return true
    end,
    setWaterSnapshot=function() return true end,
    appendLog=function() end,
}
BunkerCampaign.Util.worldAgeHours = function() return 10 end

local cleaned = 0
local qaMutations = 0
BunkerCampaignToxicMP.Server = {
    getPlayerRecord=function() return {surfaceContamination=80,gearContamination=80} end,
    cleanPlayer=function() cleaned = cleaned + 1; return true end,
    setPlayerSurfaceContamination=function() qaMutations = qaMutations + 1; return true end,
    applySurfaceContact=function() return true end,
    ensureZone=function() return true end,
}

function RunDecontaminationServerTests()
BunkerCampaignIntegration.DecontaminationServer.initialize()
local ordinary = {
    getUsername=function() return "ordinary" end,
    isAccessLevel=function() return false end,
    getX=function() return 9946 end,
    getY=function() return 12625 end,
    getZ=function() return -4 end,
    getInventory=function() return inventory end,
}
BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "qaContaminate", ordinary, {}
)
assert(qaMutations == 0, "ordinary clients must not execute QA mutations")

BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "loadReagent", player, {}
)
local decon = persisted["BunkerCampaign.IntegrationState"].decontamination
assert(tabletUsed == 1 and decon.reagentUnits == 50, "loading the mixer must consume one real NBC tablet")

BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "startCycle", player, {mode="automatic"}
)
assert(decon.activeCycle and decon.activeCycle.mode == "automatic", "valid resources must start an automatic cycle")
assert(power.consumers.decontamination.requested and power.consumers.decontamination.allocated,
    "automatic cycle must request and receive grid power")
assert(persisted.WaterPipes.Barrels.bunker.w == 1000, "automatic cycle must debit exactly twenty liters")
assert(decon.reagentUnits == 45, "automatic cycle must debit mixer concentration once")

BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "qaFinishCycle", player, {}
)
BunkerCampaignIntegration.DecontaminationServer.update()
now = now + 1000
BunkerCampaignIntegration.DecontaminationServer.update()
assert(cleaned == 1, "completed cycle must invoke authoritative contamination cleanup once")
assert(decon.activeCycle == nil and decon.status == "idle", "completed cycle must release the chamber")
assert(not power.consumers.decontamination.requested, "completed cycle must release the power consumer")

print("BunkerCampaign decontamination server tests passed")
end
