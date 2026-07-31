local empty = {
    Pumps = {}, Pipes = {}, Valves = {}, Flowmeters = {}, Barrels = {}, Sprinklers = {}, Buildings = {},
}
local absentPump, absentChanged = BunkerCampaignIntegration.WaterpipesAdapter.ensureBunkerPump(empty, false, true)
assert(absentPump == nil, "adapter must not create a pump before its world object is loaded")
assert(absentChanged == false, "valid empty Waterpipes state must remain unchanged")

local pump, created = BunkerCampaignIntegration.WaterpipesAdapter.ensureBunkerPump(empty, true, true)
assert(created and pump ~= nil, "loaded bunker pump must receive a server-side Waterpipes record")
assert(pump.source == "TaintedWater", "bunker well must be represented as a tainted underground source")
assert(pump.filter == 100 and pump.active == true, "new bunker pump must start filtered and active")

empty.Flowmeters["9954-12615--4"] = { x = 9954, y = 12615, z = -4, f = 600 }
empty.Barrels.inside = { x = 9952, y = 12603, z = -5, w = 250, wmax = 1000, m = "Water" }
empty.Barrels.outside = { x = 10, y = 10, z = 0, w = 900, wmax = 1000, m = "TaintedWater" }

local sample = BunkerCampaignIntegration.WaterpipesAdapter.sample(empty)
assert(sample.status == "operational", "healthy filtered bunker pump must be operational")
assert(sample.stored == 2.5 and sample.capacity == 10, "only bunker storage must be counted and converted to liters")
assert(sample.contamination == 0, "filtered source and clean reserve must be clean")
assert(sample.flowPerMinute == 6, "bunker flowmeter must supply measured liters per minute")
assert(sample.powerDemandKw == 1.5, "active pump must expose nominal power demand")

local filterChanged, filterUse = BunkerCampaignIntegration.WaterpipesAdapter.consumeTreatmentFilter(empty, 6)
assert(filterChanged and math.abs(pump.filter - 99.4) < 0.0001
    and math.abs(filterUse - 0.006) < 0.0001,
    "six liters of dirty well water must visibly debit the 1000-liter treatment charge")

assert(BunkerCampaignIntegration.WaterpipesAdapter.availableBunkerWater(empty, true) == 2.5,
    "decontamination must see only clean bunker water")
local consumed, liters = BunkerCampaignIntegration.WaterpipesAdapter.consumeBunkerWater(empty, 1.5, true)
assert(consumed and liters == 1.5, "water reservation must consume the exact requested amount")
assert(empty.Barrels.inside.w == 100, "water reservation must debit Waterpipes storage once")
local rejected = BunkerCampaignIntegration.WaterpipesAdapter.consumeBunkerWater(empty, 2, true)
assert(not rejected and empty.Barrels.inside.w == 100, "failed reservation must leave Waterpipes storage unchanged")

BunkerCampaignIntegration.WaterpipesAdapter.fillBunkerWater(empty)
assert(empty.Barrels.inside.w == empty.Barrels.inside.wmax and empty.Barrels.inside.m == "Water",
    "QA fill must restore bunker barrels with clean water")
local fullFilter = pump.filter
sample = BunkerCampaignIntegration.WaterpipesAdapter.sample(empty)
assert(sample.storageFull and sample.flowPerMinute == 0,
    "a full bunker reserve must report zero accepted pump flow")
local fullFilterChanged, fullFilterUse =
    BunkerCampaignIntegration.WaterpipesAdapter.consumeTreatmentFilter(empty, sample.flowPerMinute)
assert(not fullFilterChanged and fullFilterUse == 0 and pump.filter == fullFilter,
    "a full bunker reserve must not consume the treatment filter")

pump.filter = 0
sample = BunkerCampaignIntegration.WaterpipesAdapter.sample(empty)
assert(sample.status == "contaminated", "unfiltered underground source must be contaminated")
assert(sample.contamination == 1, "unfiltered source contamination must be explicit")

pump.active = false
sample = BunkerCampaignIntegration.WaterpipesAdapter.sample(empty)
assert(sample.flowPerMinute == 0, "an inactive pump must not report a stale flowmeter value")
pump.active = true

pump.burn = true
sample = BunkerCampaignIntegration.WaterpipesAdapter.sample(empty)
assert(sample.status == "failed", "burned pump must override contamination status")

local originalSyncCalls = 0
local addedMedium, addedAmount = nil, 0
local receiverMd = {waterAmount=0,waterMaxAmount=5}
local properties = {set=function() end,unset=function() end}
local receiver = {
    getFluidContainer=function() return {} end,
    addFluid=function(self, medium, amount) addedMedium, addedAmount = medium, amount end,
    getModData=function() return receiverMd end,
    getSprite=function() return {getProperties=function() return properties end} end,
    transmitModData=function() end,
    sync=function() end,
}
local objectList = {
    size=function() return 1 end,
    get=function(self, index) return index == 0 and receiver or nil end,
}
getCell = function()
    return {getGridSquare=function()
        return {getObjects=function() return objectList end}
    end}
end
FluidType = {Water="clean-fluid",TaintedWater="tainted-fluid"}
IsoFlagType = {taintedWater="taintedWater"}
WPIso = {
    IsBarrel=function(object) return object == receiver end,
    GetWaterStatus=function() return 0, 5 end,
    SyncBarrel=function() originalSyncCalls = originalSyncCalls + 1 end,
}
assert(BunkerCampaignIntegration.WaterpipesAdapter.installTaintedFluidSyncPatch(),
    "WaterPipes tainted-fluid compatibility patch must install")
local taintedReceiver = {x=9952,y=12603,z=-5,w=500,wmax=500,m="TaintedWater"}
WPIso.SyncBarrel(taintedReceiver)
assert(originalSyncCalls == 0 and addedMedium == "tainted-fluid" and addedAmount == 5,
    "a bunker fluid-container receiver must receive TaintedWater instead of hard-coded clean Water")
assert(taintedReceiver.w == 0 and receiverMd.BunkerCampaignWaterMedium == "TaintedWater",
    "tainted physical synchronization must debit the pending buffer and preserve its medium")

print("BunkerCampaign Waterpipes adapter tests passed")
