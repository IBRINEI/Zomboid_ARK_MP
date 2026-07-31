local sourceAmount = 5
local sample = {
    amount=0,
    getAmount=function(self) return self.amount end,
    Empty=function(self) self.amount=0 end,
    addFluid=function(self, medium, amount) self.medium=medium; self.amount=amount end,
}
local source = {
    getModData=function() return {BunkerCampaignWaterMedium="TaintedWater"} end,
    getFluidAmount=function() return sourceAmount end,
    moveFluidToTemporaryContainer=function(self, amount)
        local moved=math.min(sourceAmount,amount); sourceAmount=sourceAmount-moved; sample.amount=moved; return sample
    end,
}
local target = {
    amount=0,
    addFluid=function(self, medium, amount) self.medium=medium; self.amount=self.amount+amount end,
}
local item = {
    getFluidContainer=function() return target end,
    syncItemFields=function(self) self.synced=true end,
}

ISTakeWaterAction.transferFluid({waterObject=source,item=item}, 2)
assert(target.medium == "tainted-fluid" and target.amount == 2,
    "a marked legacy sink must fill inventory containers with TaintedWater")
assert(sourceAmount == 3 and item.synced and item.sent and sample.disposed,
    "the tainted transfer must debit the source and synchronize the item")

local clean = {
    getModData=function() return {BunkerCampaignWaterMedium="Water"} end,
    getFluidAmount=function() return 5 end,
}
ISTakeWaterAction.transferFluid({waterObject=clean,item=item}, 1)
assert(WaterTakeOriginalCalls() == 1,
    "clean and unrelated water sources must remain on the vanilla transfer path")

print("BunkerCampaign tainted take-water server patch tests passed")
