local service = BunkerCampaignIntegration.WaterService
assert(service.available("clean") == 10, "service must report clean Waterpipes liters")

local ok, code, liters, id = service.consume(3, "clean", "test", "request-1")
assert(ok and code == "consumed" and liters == 3 and id == "request-1",
    "first transaction must consume the exact amount")
assert(service.available("clean") == 7, "first transaction must debit storage")

local repeated, repeatedCode, repeatedLiters = service.consume(3, "clean", "test", "request-1")
assert(repeated and repeatedCode == "consumed" and repeatedLiters == 3,
    "replayed transaction must return its original result")
assert(service.available("clean") == 7, "replayed transaction must not debit storage twice")

local rejected = service.consume(8, "clean", "test", "request-2")
assert(not rejected and service.available("clean") == 7,
    "failed transaction must leave storage unchanged")

local foundTainted = service.setStorageForQa("TaintedWater", 0.5)
assert(foundTainted and service.available("clean") == 0 and service.available("tainted") == 10,
    "QA storage control must create a known tainted-water state")
local foundEmpty = service.setStorageForQa(nil, 0)
assert(foundEmpty and service.available("tainted") == 0,
    "QA storage control must create a known empty state")
assert(service.setPumpForQa(0.25, 0.10, false), "QA pump control must find the bunker pump")
local sample = service.sample()
assert(sample.pumpCondition == 0.25 and sample.filterRemaining == 0.10,
    "QA pump control must mutate physical Waterpipes condition and filter")

print("BunkerCampaign water-service tests passed")
