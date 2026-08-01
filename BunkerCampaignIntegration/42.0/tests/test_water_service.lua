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

WaterServiceEnablePhysicalReceiver()
assert(service.setStorageForQa("TaintedWater", 0.5), "QA must find a loaded physical receiver")
local physicalAmount, physicalMedium = WaterServicePhysicalState()
assert(physicalAmount == 10 and physicalMedium == "TaintedWater",
    "tainted QA fill must update the actual sink fluid, not only Waterpipes ModData")
local physicalSample = service.sample()
assert(physicalSample.taintedStored == 20 and physicalSample.cleanStored == 0,
    "physical sink contents must be included in the authoritative water snapshot")
assert(service.setStorageForQa(nil, 0), "QA empty must find the physical receiver")
physicalAmount = WaterServicePhysicalState()
assert(physicalAmount == 0 and service.sample().stored == 0,
    "QA empty must drain both virtual buffers and physical sinks")

print("BunkerCampaign water-service tests passed")
