local worldTime = {
    hours = 10,
    getWorldAgeHours = function(self) return self.hours end,
}

getGameTime = function() return worldTime end
getGametimeTimestamp = function() return 10000 end
isClient = function() return false end
isServer = function() return true end

local function event()
    local result = { handlers = {} }
    result.Add = function(handler) table.insert(result.handlers, handler) end
    return result
end

Events = {
    OnInitGlobalModData = event(),
    EveryOneMinute = event(),
    OnClientCommand = event(),
}

local persisted = {}
ModData = {
    getOrCreate = function(key)
        if not persisted[key] then persisted[key] = {} end
        return persisted[key]
    end,
}

local packets = {}
sendServerCommand = function(...)
    packets[#packets + 1] = { ... }
end

local function player(name, admin, x, y, z)
    return {
        getUsername = function(self) return name end,
        isAccessLevel = function(self, level) return admin and level == "admin" end,
        getX = function(self) return x or 0 end,
        getY = function(self) return y or 0 end,
        getZ = function(self) return z or 0 end,
    }
end

function RunBunkerCampaignServerTests()
BunkerCampaign.CampaignState.initialize(true)
local firstReference = BunkerCampaign.CampaignState.get()
assert(firstReference.version == 6, "server must initialize versioned state")
assert(#firstReference.auditLog > 0, "initialization must be audited")
assert(firstReference.bunker.modules.water.status == "offline", "water module must migrate with safe defaults")
assert(firstReference.bunker.modules.water.adapterOnline == false, "water adapter must start offline")
assert(firstReference.bunker.modules.power.gridOnline == true, "main generator must bootstrap the bunker grid")
assert(firstReference.bunker.modules.power.consumers.decontamination.requested == false, "decontamination load must start idle")
assert(firstReference.bunker.modules.ventilation.operating == true, "ventilation must receive bootstrap power")

local ok = BunkerCampaign.CampaignState.setVentilationEnabled(false, "admin-user")
assert(ok, "valid server mutation must succeed")
assert(firstReference.bunker.modules.ventilation.enabled == false, "server mutation must change persistent state")
local co2Before = firstReference.bunker.modules.ventilation.co2
BunkerCampaign.CampaignState.updateOneMinute()
assert(firstReference.bunker.modules.ventilation.co2 >= co2Before,
    "empty bunker must not create artificial CO2 while ventilation is off")

BunkerCampaign.CampaignState.initialize(false)
assert(BunkerCampaign.CampaignState.get() == firstReference, "reload must reuse the ModData table")

local contaminationOk = BunkerCampaign.CampaignState.setExternalContamination(0.75, "test-adapter")
assert(contaminationOk, "trusted adapter contamination update must succeed")
assert(firstReference.bunker.modules.ventilation.externalContamination == 0.75, "trusted contamination must be stored")
local invalidContamination = BunkerCampaign.CampaignState.setExternalContamination("high", "test-adapter")
assert(not invalidContamination, "non-numeric contamination must be rejected")

local waterOk = BunkerCampaign.CampaignState.setWaterSnapshot({
    adapterOnline = true,
    pumpActive = true,
    pumpCondition = 0.75,
    status = "operational",
    filterRemaining = 0.5,
    stored = 800,
    capacity = 500,
    contamination = 0.1,
    flowPerMinute = 120,
    powerDemandKw = 1.5,
    source = "underground_well",
}, "test-adapter")
assert(waterOk, "trusted water adapter update must succeed")
assert(firstReference.bunker.modules.water.stored == 500, "stored water must not exceed capacity")
assert(firstReference.bunker.modules.water.source == "underground_well", "water source must be stored")
assert(BunkerCampaign.CampaignState.snapshot().water.flowPerMinute == 120, "water state must be sent to clients")
local invalidWater = BunkerCampaign.CampaignState.setWaterSnapshot("wet", "test-adapter")
assert(not invalidWater, "malformed water snapshot must be rejected")

local normalPlayer = player("survivor", false)
local adminPlayer = player("administrator", true, 9966, 12622, -4)
local bunkerPlayer = player("bunker-survivor", false, 9966, 12622, -4)
local enabledBeforeAttack = firstReference.bunker.modules.ventilation.enabled
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "setVentilation", normalPlayer, { enabled = true })
assert(firstReference.bunker.modules.ventilation.enabled == enabledBeforeAttack, "non-admin mutation must be rejected")

BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "setVentilation", adminPlayer, { enabled = "true" })
assert(firstReference.bunker.modules.ventilation.enabled == enabledBeforeAttack, "malformed mutation must be rejected")

BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "setVentilation", adminPlayer, { enabled = true })
assert(firstReference.bunker.modules.ventilation.enabled == true, "admin boolean mutation must be accepted")

BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "setGenerator", adminPlayer, { id = "main", requested = false })
assert(firstReference.bunker.modules.power.generators.main.requested == false, "admin must be able to stop the main generator")
assert(firstReference.bunker.modules.power.emergencyMode == true, "battery-backed control must survive a generator outage")
assert(firstReference.bunker.modules.ventilation.operating == false, "ventilation must stop when its load is shed")

BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "setGenerator", adminPlayer, { id = "backup", requested = true })
assert(firstReference.bunker.modules.power.gridOnline == true, "backup generator must restore the physical grid request")
assert(firstReference.bunker.modules.ventilation.operating == true, "ventilation must resume after power allocation returns")

BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "setConsumer", bunkerPlayer, { id = "water", requested = false })
assert(firstReference.bunker.modules.power.consumers.water.requested == false, "ordinary players inside the bunker must operate infrastructure")

local packetsBeforeRequest = #packets
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "requestState", normalPlayer, {})
assert(#packets > packetsBeforeRequest, "state request must receive a targeted snapshot")

print("BunkerCampaign server-state tests passed")
end
