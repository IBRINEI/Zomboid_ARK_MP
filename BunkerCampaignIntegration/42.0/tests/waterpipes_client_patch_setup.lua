BunkerCampaignIntegration = {}
TARepairPump = nil
ISTakeWaterAction = {
    new=function(self, character, item, waterObject, tainted)
        return {waterObject=waterObject, waterTaintedCL=tainted}
    end,
}
