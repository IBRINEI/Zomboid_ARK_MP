local Model = BunkerCampaignIntegration.DecontaminationModel

local state = Model.createDefault()
assert(state.areas.dirty == 0 and state.areas.chamber == 0 and state.areas.clean == 0,
    "dirty/chamber/clean contamination areas must initialize independently")
local ok, code = Model.precheck("automatic", {
    cleanWaterLiters=100,
    powerAllocated=true,
    mixerUnits=50,
})
assert(ok and code == nil, "automatic cycle must accept complete resources")

local missingPower, powerCode = Model.precheck("automatic", {
    cleanWaterLiters=100,
    powerAllocated=false,
    mixerUnits=50,
})
assert(not missingPower and powerCode == "power_required", "automatic cycle must require allocated power")

local cycle = Model.start(state, "automatic", "tester", 12)
assert(cycle and state.status == "running", "valid cycle must enter running state")
local duplicate, duplicateCode = Model.start(state, "manual", "tester", 12)
assert(not duplicate and duplicateCode == "cycle_active", "only one chamber cycle may run at once")

local complete, status = Model.advance(state, 5, true)
assert(not complete and status == "running", "partial elapsed time must not finish the cycle")
local remaining = state.activeCycle.remainingSeconds
complete, status = Model.advance(state, 5, false)
assert(not complete and status == "paused" and state.activeCycle.remainingSeconds == remaining,
    "power loss must pause without consuming cycle time")
complete = Model.advance(state, 100, true)
assert(complete, "restored power must allow the cycle to complete")
Model.finish(state, "automatic_complete")
assert(state.status == "idle" and state.activeCycle == nil, "finished cycle must return to idle")

print("BunkerCampaign decontamination model tests passed")
