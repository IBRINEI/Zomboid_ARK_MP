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
ISWashClothing = {
    GetRequiredSoap=function() return 0 end,
    GetRequiredWater=function() return 0 end,
    GetSoapRemaining=function() return 0 end,
    new=function() return {maxTime=100} end,
    complete=function() return true end,
}
ISWashYourself = {
    GetRequiredSoap=function() return 0 end,
    GetRequiredWater=function() return 0 end,
    new=function() return {maxTime=100} end,
    complete=function() return true end,
}
Fluid = { CleaningLiquid="CleaningLiquid" }
isClient = function() return false end
isServer = function() return true end

local persisted = {
    ["BunkerCampaign.IntegrationState"] = {},
    BanditWeekOneTheArk = {
        airintakes={{x=9940,y=12633,z=0,broken=false,condition=1}},
    },
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
local tabletRemoved = 0
local inventory
local tablet = { getContainer=function() return inventory end }
local soapUses = 20
local soap = {
    className="DrainableComboItem",
    getFullType=function() return "Base.Soap2" end,
    getCurrentUses=function() return soapUses end,
    UseAndSync=function() soapUses = soapUses - 1 end,
}
local manualItemContamination = 50
local manualItem = { getID=function() return 991 end, getFullType=function() return "Base.Hammer" end }
local inventoryItems = {
    size=function() return 2 end,
    get=function(self, index) return index == 0 and soap or manualItem end,
}
local addedItems = 0
local syncedAddedItems = 0
inventory = {
    getFirstTypeRecurse=function(self, itemType)
        if itemType == "Bandits.NBCTablets" and tabletRemoved == 0 then return tablet end
        return nil
    end,
    Remove=function(self, item) assert(item == tablet); tabletRemoved = tabletRemoved + 1 end,
    getItems=function() return inventoryItems end,
    AddItem=function(self, itemType)
        addedItems = addedItems + 1
        return { itemType=itemType }
    end,
}
instanceof = function(object, className) return object and object.className == className end
ZomboidGlobals = { CleanStainCleaningFluidAmount=0.1 }
sendRemoveItemFromContainer = function(container, item)
    assert(container == inventory and item == tablet, "tablet removal must be synchronized")
end
sendAddItemToContainer = function(container, item)
    assert(container == inventory and item, "QA inventory sync must use the authoritative container")
    syncedAddedItems = syncedAddedItems + 1
end
local player = {
    getUsername=function() return "decon-tester" end,
    isAccessLevel=function(self, level) return level == "admin" end,
    getX=function() return 9946 end,
    getY=function() return 12625 end,
    getZ=function() return -4 end,
    getInventory=function() return inventory end,
    isDead=function() return false end,
}
local secondPlayer = {
    getUsername=function() return "second-chamber-player" end,
    isAccessLevel=function() return false end,
    getX=function() return 9947 end,
    getY=function() return 12625 end,
    getZ=function() return -4 end,
    getInventory=function() return inventory end,
    isDead=function() return false end,
}
local online = {
    size=function() return 2 end,
    get=function(self, index) return index == 0 and player or secondPlayer end,
}
getOnlinePlayers = function() return online end
getCell = function()
    return { getGridSquare=function(self, x, y, z)
        if x == 9946 and y == 12625 and z == -4 then return {} end
        return nil
    end }
end
sendServerCommand = function() end

local power = { consumers={
    decontamination={requested=false,allocated=false},
    water={requested=true,allocated=true},
} }
local campaignWater = {requested=true,pumpRequested=true,telemetry={}}
local ventilation = {
    intakes={intake_1={x=9940,y=12633,z=0,broken=false,condition=1,status="operational"}},
}
local refueledGenerator = nil
local stateTouches, stateBroadcasts = 0, 0
BunkerCampaign.CampaignState = {
    get=function() return { bunker={modules={power=power,ventilation=ventilation,water=campaignWater}} } end,
    setConsumerRequested=function(id, requested)
        power.consumers[id].requested = requested
        power.consumers[id].allocated = requested
        if id == "water" then
            campaignWater.requested = requested
            campaignWater.pumpRequested = requested
        end
        return true
    end,
    setWaterSnapshot=function() return true end,
    appendLog=function() end,
    touch=function() stateTouches = stateTouches + 1 end,
    broadcast=function() stateBroadcasts = stateBroadcasts + 1 end,
    refuelGenerator=function(id) refueledGenerator = id; return true end,
}
BunkerCampaign.Util.worldAgeHours = function() return 10 end

local cleaned = 0
local qaMutations = 0
BunkerCampaignToxicMP = BunkerCampaignToxicMP or {}
BunkerCampaignToxicMP.Constants = { SURFACE_DIRTY=40, SURFACE_TRACE=0.5 }
local cleanedWorldItems, cleanedCorpses = 0, 0
local worldRemovalFractions = {}
BunkerCampaignToxicMP.Server = {
    getPlayerRecord=function() return {surfaceContamination=80,gearContamination=80} end,
    cleanPlayer=function() cleaned = cleaned + 1; return true end,
    setPlayerSurfaceContamination=function() qaMutations = qaMutations + 1; return true end,
    applySurfaceContact=function() return true end,
    ensureZone=function() return true end,
    cleanWorldInBounds=function(bounds, removalFraction)
        worldRemovalFractions[#worldRemovalFractions + 1] = removalFraction
        cleanedWorldItems, cleanedCorpses = 3, 1
        return true, cleanedWorldItems, cleanedCorpses
    end,
    findCarriedItem=function(targetPlayer, itemId)
        return tonumber(itemId) == 991 and manualItem or nil
    end,
    getItemContamination=function(item)
        return item == manualItem and manualItemContamination or 0
    end,
    cleanItem=function(targetPlayer, item)
        assert(item == manualItem)
        manualItemContamination = 0
        return true
    end,
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
assert(tabletRemoved == 1 and decon.reagentUnits == 50,
    "loading the mixer must remove one complete NBC tablet")

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
assert(cleaned == 2, "one completed chamber cycle must clean every player who was inside at its start")
assert(cleanedWorldItems == 3 and cleanedCorpses == 1,
    "automatic cycle must clean loose world items and corpse containers")
assert(worldRemovalFractions[1] == 1,
    "automatic cycle must fully clean world items and corpse containers")
assert(decon.activeCycle == nil and decon.status == "idle", "completed cycle must release the chamber")
assert(not power.consumers.decontamination.requested, "completed cycle must release the power consumer")

BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "startCycle", player, {mode="emergency"}
)
assert(decon.activeCycle and decon.activeCycle.mode == "emergency",
    "valid resources must start an emergency cycle")
BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "qaFinishCycle", player, {}
)
now = now + 1000
BunkerCampaignIntegration.DecontaminationServer.update()
assert(worldRemovalFractions[2] == 0.5,
    "emergency cycle must apply its fifty-percent gear cleaning to world items and corpses")
persisted.WaterPipes.Barrels.bunker.w = 1000

BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "manualWashBunker", player, {target="item", itemId=991}
)
assert(manualItemContamination == 0, "individual bunker wash must clean the selected item")
assert(soapUses == 18, "50% contamination must consume two soap uses without deleting the soap bar")
assert(persisted.WaterPipes.Barrels.bunker.w == 100,
    "individual bunker wash must consume nine liters from bunker storage")

manualItemContamination = 50
BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "manualWashVanilla", player, {target="item", itemId=991}
)
assert(manualItemContamination == 50,
    "legacy forged vanilla wash commands must be ignored")
assert(BunkerCampaignIntegration.ManualWashShared.getBodyContamination(player) == 80,
    "the shared vanilla action must read authoritative body contamination")
BunkerCampaignIntegration.ManualWashShared.onVanillaComplete(player, "item", manualItem)
assert(manualItemContamination == 0,
    "server completion of a vanilla wash must clean the selected item")

BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "qaGiveSupplies", player, {}
)
assert(addedItems == 10 and syncedAddedItems == 10,
    "QA supplies must be added on the server and explicitly synchronized to the client")

BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "qaRefuelGenerator", player, {generator="backup"}
)
assert(refueledGenerator == "backup", "QA refuel must target the requested logical generator")

BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "qaSetIntake", player,
    {x=9940,y=12633,z=0,broken=true}
)
assert(persisted.BanditWeekOneTheArk.airintakes[1].broken
    and ventilation.intakes.intake_1.broken and ventilation.intakes.intake_1.status == "failed",
    "QA intake failure must mutate both the Ark source state and campaign snapshot immediately")
assert(stateTouches == 1 and stateBroadcasts == 1,
    "QA intake failure must publish one authoritative state revision")

BunkerCampaignIntegration.DecontaminationServer.onClientCommand(
    "BunkerCampaignDecontamination", "qaWaterStorage", player,
    {fillFraction=0,stopPump=true}
)
assert(not power.consumers.water.requested and persisted.WaterPipes.Barrels.bunker.w == 0,
    "empty-storage QA must stop the pump and drain the physical Waterpipes reserve")

print("BunkerCampaign decontamination server tests passed")
end
