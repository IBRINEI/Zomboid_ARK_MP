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
assert(firstReference.version == 8, "server must initialize versioned state")
assert(#firstReference.auditLog > 0, "initialization must be audited")
assert(firstReference.bunker.modules.water.status == "offline", "water module must migrate with safe defaults")
assert(firstReference.bunker.modules.water.adapterOnline == false, "water adapter must start offline")
assert(firstReference.bunker.modules.power.gridOnline == true, "main generator must bootstrap the bunker grid")
assert(firstReference.bunker.modules.power.consumers.decontamination.requested == false, "decontamination load must start idle")
assert(firstReference.bunker.modules.power.consumers.heating.requested == true,
    "heating must be an explicit server power consumer")
assert(firstReference.bunker.modules.heating.powerAllocated == true,
    "heating must receive bootstrap generator power")
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
local bunkerPlayer = player("bunker-survivor", false, 9963, 12627, -4)
local filterPlayer = player("filter-technician", false, 9966, 12622, -4)
local incomingFilter
local returnedFilterDelta = nil
local filterInventory = {}
incomingFilter = {
    getUsedDelta=function() return 0.37 end,
    getModData=function() return {} end,
    getContainer=function() return filterInventory end,
}
filterInventory.getFirstTypeRecurse=function(self, itemType)
    return itemType == "Base.GasmaskFilter" and incomingFilter or nil
end
filterInventory.Remove=function(self, item) assert(item == incomingFilter); incomingFilter = nil end
filterInventory.AddItem=function(self, itemType)
    assert(itemType == "Base.GasmaskFilter")
    local md = {}
    return {
        getModData=function() return md end,
        setUsedDelta=function(self, value) returnedFilterDelta = value end,
        setName=function() end,
        syncItemFields=function() end,
    }
end
filterPlayer.getInventory=function() return filterInventory end
sendRemoveItemFromContainer=function() end
sendAddItemToContainer=function() end
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

assert(BunkerCampaign.CampaignState.registerRoom({
    id="server_test_room", label="Server test room", kind="habitable",
    bounds={x1=9964,x2=9968,y1=12620,y2=12624,z=-4},
    vents={{x=9966,y=12620,z=-4}}, connections={},
}), "server test heating room must register")
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "setHeatingTarget", bunkerPlayer, {
    temperature=19,
})
assert(firstReference.bunker.modules.heating.targetTemperature == 19,
    "ordinary bunker operators must set the heating target")
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "setHeatingRoom", bunkerPlayer, {
    roomId="server_test_room", enabled=false,
})
assert(firstReference.bunker.modules.heating.rooms.server_test_room.heatingEnabled == false,
    "room heating isolation must be server authoritative")

Perks = { Electricity={}, Mechanics={}, MetalWelding={} }
local controllerDefinition = BunkerCampaign.HeatingComponents.get("controller")
local physicalSprite = { getName=function() return controllerDefinition.sprite end }
local physicalObject = { getSprite=function() return physicalSprite end }
local physicalObjects = {
    size=function() return 1 end,
    get=function(self, index) return index == 0 and physicalObject or nil end,
}
getCell = function()
    return { getGridSquare=function() return {
        getObjects=function() return physicalObjects end,
    } end }
end
local materialCounts = {
    ["Base.Screwdriver"]=1,
    ["Base.ElectronicsScrap"]=2,
    ["Base.ElectricWire"]=1,
}
local repairInventory = {}
repairInventory.getNumberOfItem=function(self, fullType)
    return materialCounts[fullType] or 0
end
repairInventory.getFirstTypeRecurse=function(self, fullType)
    if (materialCounts[fullType] or 0) <= 0 then return nil end
    return {
        getContainer=function() return repairInventory end,
        fullType=fullType,
    }
end
repairInventory.Remove=function(self, item)
    materialCounts[item.fullType] = materialCounts[item.fullType] - 1
end
local repairXp = { AddXP=function() end }
local repairPlayer = player("heating-technician", false,
    controllerDefinition.x, controllerDefinition.y, controllerDefinition.z)
repairPlayer.getInventory=function() return repairInventory end
repairPlayer.getPerkLevel=function() return 10 end
repairPlayer.getXp=function() return repairXp end
assert(BunkerCampaign.CampaignState.triggerHeatingFault(
    "controller", "major", "test"), "test controller fault must be created")
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign",
    "diagnoseHeatingComponent", repairPlayer, { componentId="controller" })
assert(firstReference.bunker.modules.heating.components.controller.diagnosed,
    "component diagnosis must be server authoritative")
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign",
    "repairHeatingComponent", repairPlayer,
    { componentId="controller", mode="full" })
assert(firstReference.bunker.modules.heating.components.controller.fault == "none",
    "a valid skilled repair must clear the controller fault")
assert(materialCounts["Base.ElectronicsScrap"] == 0
    and materialCounts["Base.ElectricWire"] == 0,
    "server repair must consume replacement parts")

BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "setHeating", normalPlayer, {
    enabled=false,
})
assert(firstReference.bunker.modules.heating.enabled == true,
    "a player outside the bunker must not change heating")

local qaRoom = firstReference.bunker.modules.heating.rooms.server_test_room
local qaTemperatureBefore = qaRoom.temperature
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "qaHeating", normalPlayer, {
    action="rooms", temperature=-20,
})
assert(qaRoom.temperature == qaTemperatureBefore,
    "ordinary clients must not execute heating QA mutations")

BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "qaHeating", adminPlayer, {
    action="ready",
})
local qaModules = firstReference.bunker.modules
assert(qaRoom.temperature == 5 and qaModules.heating.targetTemperature == 21,
    "cold heating QA must set a deterministic room and target temperature")
assert(qaModules.power.generators.main.requested
    and not qaModules.power.generators.backup.requested,
    "cold heating QA must provide deterministic main-generator power")
assert(not qaModules.water.requested and not qaModules.power.consumers.water.requested,
    "cold heating QA must release the competing water load")
assert(qaModules.ventilation.requestedMode == "internal_recirculation"
    and qaModules.heating.operating and qaModules.heating.reason == "heating",
    "cold heating QA must start the required air circuit and heater")

BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "qaHeating", adminPlayer, {
    action="ventilation_off",
})
assert(qaModules.heating.reason == "air_circuit_unavailable",
    "ventilation-off QA must stop heating through its air-circuit dependency")

BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "qaHeating", adminPlayer, {
    action="component", componentId="controller", state="major",
})
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "qaHeating", adminPlayer, {
    action="component", componentId="pipe_manifold", state="major",
})
assert(qaModules.heating.components.controller.fault == "controller_offline"
    and qaModules.heating.components.pipe_manifold.fault == "pipe_rupture"
    and qaModules.heating.components.pipe_manifold.diagnosed,
    "component QA must set exact diagnosed faults independently of random-failure caps")
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "qaHeating", adminPlayer, {
    action="restore_all",
})
assert(qaModules.heating.components.pipe_manifold.fault == "none"
    and qaModules.heating.components.pipe_manifold.condition == 0.90,
    "restore-all QA must return failed components to a known healthy state")

local qaKitItems, qaKitSynced = {}, 0
local qaKitInventory = {
    AddItem=function(self, fullType)
        qaKitItems[fullType] = (qaKitItems[fullType] or 0) + 1
        return {fullType=fullType}
    end,
}
local qaKitPlayer = player("qa-heating-technician", true, 9966, 12622, -4)
qaKitPlayer.getInventory=function() return qaKitInventory end
local previousSendAddItemToContainer = sendAddItemToContainer
sendAddItemToContainer=function(container, item)
    assert(container == qaKitInventory and item.fullType,
        "heating QA kit must synchronize every added item")
    qaKitSynced = qaKitSynced + 1
end
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign",
    "qaHeatingRepairKit", normalPlayer, {})
assert(qaKitSynced == 0 and qaKitItems["Base.Screwdriver"] == nil,
    "ordinary clients must not receive administrator heating QA supplies")
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign",
    "qaHeatingRepairKit", qaKitPlayer, {})
assert((qaKitItems["Base.Screwdriver"] or 0) >= 1
    and (qaKitItems["Base.BlowTorch"] or 0) >= 1
    and (qaKitItems["Base.Wrench"] or 0) >= 1
    and (qaKitItems["Base.ElectronicsScrap"] or 0) >= 3
    and qaKitSynced > 0,
    "heating QA kit must include and synchronize tools plus repair materials")
sendAddItemToContainer = previousSendAddItemToContainer

local previousVentFilter = firstReference.bunker.modules.ventilation.filterBank.remaining
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "replaceVentilationFilter", filterPlayer, {})
assert(firstReference.bunker.modules.ventilation.filterBank.remaining == 0.37,
    "ventilation replacement must read the vanilla drainable Remaining value")
assert(math.abs(returnedFilterDelta - previousVentFilter) < 0.0001,
    "removed ventilation cartridge must preserve Remaining instead of Condition")

local packetsBeforeRequest = #packets
BunkerCampaign.ServerCommands.onClientCommand("BunkerCampaign", "requestState", normalPlayer, {})
assert(#packets > packetsBeforeRequest, "state request must receive a targeted snapshot")

local packetsBeforeEmptyBroadcast = #packets
getOnlinePlayers = function()
    return { size=function() return 0 end }
end
BunkerCampaign.CampaignState.broadcast()
assert(#packets == packetsBeforeEmptyBroadcast,
    "broadcast must not touch the dedicated-server network before players are available")
getOnlinePlayers = nil

local ventilation = firstReference.bunker.modules.ventilation
BunkerCampaign.VentilationSimulation.setMode(ventilation, "external_filtration")
BunkerCampaign.CampaignState.setGeneratorRequested("main", true, "test")
local adapterFlow = 1
BunkerCampaign.CampaignState.addPowerListener(function()
    adapterFlow = adapterFlow + 1
    BunkerCampaign.CampaignState.setWaterSnapshot({
        adapterOnline=true, pumpActive=true, pumpCondition=1, status="operational",
        filterRemaining=0.5, stored=100, capacity=500, contamination=0,
        flowPerMinute=adapterFlow, powerDemandKw=1.5, source="underground_well",
    }, "mid-tick test adapter")
end)
BunkerCampaign.CampaignState.minutesSinceSync = 0
local packetsBeforeTick = #packets
BunkerCampaign.CampaignState.updateOneMinute()
assert(#packets == packetsBeforeTick + 1,
    "mid-tick adapter changes must publish one atomic end-of-tick snapshot")
local tickSnapshot = packets[#packets][3]
assert(tickSnapshot.revision == firstReference.revision,
    "published life-support snapshot must use the final tick revision")
assert(tickSnapshot.ventilation.telemetry.outsideExchangeM3PerMinute > 0,
    "published life-support snapshot must contain final ventilation telemetry")

print("BunkerCampaign server-state tests passed")
end
