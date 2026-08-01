require "TimedActions/ISTakeWaterAction"

if isClient() then return end

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local function isMarkedTainted(object)
    local md = object and object.getModData and object:getModData() or nil
    return md and md.BunkerCampaignWaterMedium == "TaintedWater"
end

if ISTakeWaterAction and not ISTakeWaterAction.BunkerCampaignTaintedTransferPatched then
    local originalTransferFluid = ISTakeWaterAction.transferFluid

    function ISTakeWaterAction:transferFluid(amount)
        amount = tonumber(amount) or 0
        if amount <= 0 or not isMarkedTainted(self.waterObject)
            or not FluidType or not FluidType.TaintedWater then
            return originalTransferFluid(self, amount)
        end
        if not self.waterObject or self.waterObject:getFluidAmount() <= 0 then return end

        local target = self.item and self.item:getFluidContainer() or nil
        if self.item and not target then return originalTransferFluid(self, amount) end

        local sample = self.waterObject:moveFluidToTemporaryContainer(amount)
        local moved = sample and tonumber(sample:getAmount()) or 0
        if moved <= 0 then
            if sample and FluidContainer then FluidContainer.DisposeContainer(sample) end
            return
        end

        if target then
            target:addFluid(FluidType.TaintedWater, moved)
            self.item:syncItemFields()
            sendItemStats(self.item)
        else
            sample:Empty()
            sample:addFluid(FluidType.TaintedWater, moved)
            self.character:DrinkFluid(sample, 1)
        end
        if FluidContainer then FluidContainer.DisposeContainer(sample) end
    end

    ISTakeWaterAction.BunkerCampaignTaintedTransferPatched = true
end

BunkerCampaignIntegration.isMarkedTaintedWater = isMarkedTainted
