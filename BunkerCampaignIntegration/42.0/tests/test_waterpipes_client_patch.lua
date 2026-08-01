local taintedObject = {
    getModData=function() return {BunkerCampaignWaterMedium="TaintedWater"} end,
    isTaintedWater=function() return false end,
}
local cleanObject = {
    getModData=function() return {BunkerCampaignWaterMedium="Water"} end,
    isTaintedWater=function() return true end,
}
local unmarkedObject = {
    getModData=function() return {} end,
    isTaintedWater=function() return true end,
}

assert(BunkerCampaignIntegration.effectiveWaterTaint(taintedObject, false) == true,
    "the replicated tainted-water marker must override a stale client sprite flag")
assert(BunkerCampaignIntegration.effectiveWaterTaint(cleanObject, true) == false,
    "the replicated clean-water marker must clear a stale client sprite flag")
assert(BunkerCampaignIntegration.effectiveWaterTaint(unmarkedObject, nil) == true,
    "unmarked water objects must preserve vanilla taint detection")
assert(ISTakeWaterAction:new(nil, nil, taintedObject, false).waterTaintedCL == true,
    "vanilla take-water actions must receive the replicated bunker medium")

print("BunkerCampaign Waterpipes client patch tests passed")
