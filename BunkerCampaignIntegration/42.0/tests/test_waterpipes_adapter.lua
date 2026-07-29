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

pump.filter = 0
sample = BunkerCampaignIntegration.WaterpipesAdapter.sample(empty)
assert(sample.status == "contaminated", "unfiltered underground source must be contaminated")
assert(sample.contamination == 1, "unfiltered source contamination must be explicit")

pump.burn = true
sample = BunkerCampaignIntegration.WaterpipesAdapter.sample(empty)
assert(sample.status == "failed", "burned pump must override contamination status")

print("BunkerCampaign Waterpipes adapter tests passed")
