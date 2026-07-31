isClient = function() return false end
BunkerCampaignIntegration = {}
FluidType = {TaintedWater="tainted-fluid"}
FluidContainer = {DisposeContainer=function(sample) sample.disposed=true end}
sendItemStats = function(item) item.sent=true end

local originalCalls = 0
ISTakeWaterAction = {
    transferFluid=function() originalCalls=originalCalls+1 end,
}

function WaterTakeOriginalCalls() return originalCalls end
