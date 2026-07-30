require "TimedActions/ISWashClothing"
require "TimedActions/ISWashYourself"
require "BunkerCampaignIntegration/Constants"
require "BunkerCampaignToxicMP/Constants"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local IntegrationConstants = BunkerCampaignIntegration.Constants
local ToxicConstants = BunkerCampaignToxicMP.Constants
local Rules = IntegrationConstants.DECONTAMINATION
local ManualWashShared = BunkerCampaignIntegration.ManualWashShared or {}
local vanillaBodySoap = ISWashYourself.GetRequiredSoap
local vanillaBodyWater = ISWashYourself.GetRequiredWater

local function contamination(item)
    if not item or not item.getModData then return 0 end
    return math.max(0, math.min(100,
        tonumber(item:getModData()[ToxicConstants.CONTAMINATION_MODDATA_KEY]) or 0))
end

local function bodyContamination(character)
    if type(ManualWashShared.getBodyContamination) == "function" then
        return math.max(0, math.min(100,
            tonumber(ManualWashShared.getBodyContamination(character)) or 0))
    end
    local status = BunkerCampaignToxicMP.Client and BunkerCampaignToxicMP.Client.status
    return math.max(0, math.min(100,
        tonumber(status and status.surfaceContamination) or 0))
end

local function contaminationUses(value)
    if value <= ToxicConstants.SURFACE_TRACE then return 0 end
    return math.max(1, math.ceil(value / Rules.MANUAL_WASH.contaminationPerAgentUse))
end

local function additionalWater(value)
    if value <= ToxicConstants.SURFACE_TRACE then return 0 end
    return Rules.MANUAL_WASH.baseWaterLiters
        + math.ceil(value / Rules.MANUAL_WASH.contaminationPerAdditionalLiter)
end

local function cleaningFluidPerUse()
    return math.max(0.001,
        tonumber(ZomboidGlobals and ZomboidGlobals.CleanStainCleaningFluidAmount) or 0.1)
end

local function addBleachToSoapList(character, soaps)
    if not character or not soaps then return soaps end
    local all = character:getInventory():getAllTypeRecurse("Base.Bleach")
    if all then
        for index = 0, all:size() - 1 do
            local item = all:get(index)
            if item and not soaps:contains(item) then soaps:add(item) end
        end
    end
    return soaps
end

local function soapList(character, recurse)
    return addBleachToSoapList(character,
        character:getInventory():getSoapList(nil, recurse ~= false))
end

local function consumeAdditionalSoap(soaps, required)
    local remaining = math.max(0, math.floor(tonumber(required) or 0))
    if not soaps then return false end
    for index = 0, soaps:size() - 1 do
        if remaining <= 0 then break end
        local soap = soaps:get(index)
        if instanceof(soap, "DrainableComboItem") then
            local take = math.min(remaining, math.max(0, soap:getCurrentUses()))
            for _ = 1, take do soap:UseAndSync() end
            remaining = remaining - take
        elseif soap:getFluidContainer() and soap:getFluidContainer():getAmount() > 0 then
            local fluid = soap:getFluidContainer()
            local take = math.min(remaining,
                math.floor(fluid:getAmount() / cleaningFluidPerUse() + 0.0001))
            if take > 0 then
                local nextAmount = math.max(0, fluid:getAmount() - take * cleaningFluidPerUse())
                if nextAmount <= 0.001 then fluid:Empty() else fluid:adjustAmount(nextAmount) end
                sendItemStats(soap)
                remaining = remaining - take
            end
        end
    end
    return remaining <= 0
end

if not BunkerCampaignIntegration.ManualWashPatched then
    BunkerCampaignIntegration.ManualWashPatched = true

    local vanillaClothingSoap = ISWashClothing.GetRequiredSoap
    local vanillaClothingWater = ISWashClothing.GetRequiredWater
    local vanillaSoapRemaining = ISWashClothing.GetSoapRemaining
    local vanillaClothingNew = ISWashClothing.new
    local vanillaClothingComplete = ISWashClothing.complete

    ISWashClothing.GetRequiredSoap = function(item)
        return vanillaClothingSoap(item) + contaminationUses(contamination(item))
    end

    ISWashClothing.GetRequiredWater = function(item)
        return math.max(vanillaClothingWater(item), additionalWater(contamination(item)))
    end

    ISWashClothing.GetSoapRemaining = function(soaps)
        local total = vanillaSoapRemaining(soaps)
        if soaps then
            for index = 0, soaps:size() - 1 do
                local item = soaps:get(index)
                if item and item:getFullType() == "Base.Bleach" and item:getFluidContainer() then
                    local fluid = item:getFluidContainer()
                    if not fluid:contains(Fluid.CleaningLiquid) then
                        total = total + math.floor(fluid:getAmount() / cleaningFluidPerUse() + 0.0001)
                    end
                end
            end
        end
        return total
    end

    ISWashClothing.new = function(self, character, sink, item, bloodAmount, dirtAmount, noSoap)
        local action = vanillaClothingNew(self, character, sink, item, bloodAmount, dirtAmount, noSoap)
        action.soaps = soapList(character, true)
        return action
    end

    ISWashClothing.complete = function(self)
        local radioactive = contamination(self.item)
        local waterBefore = self.sink:getFluidAmount()
        local requiredWater = ISWashClothing.GetRequiredWater(self.item)
        local result = vanillaClothingComplete(self)
        if result and not isClient() and radioactive > ToxicConstants.SURFACE_TRACE then
            local waterOk = waterBefore + 0.0001 >= requiredWater
            local agentOk = waterOk
                and consumeAdditionalSoap(self.soaps, contaminationUses(radioactive))
            if waterOk and agentOk
                and type(ManualWashShared.onVanillaComplete) == "function" then
                ManualWashShared.onVanillaComplete(self.character, "item", self.item)
            end
        end
        return result
    end

    local vanillaBodyNew = ISWashYourself.new
    local vanillaBodyComplete = ISWashYourself.complete

    ISWashYourself.new = function(self, character, sink)
        local action = vanillaBodyNew(self, character, sink)
        action.soaps = soapList(character, true)
        action.maxTime = math.max(100, action.maxTime)
        return action
    end

    ISWashYourself.complete = function(self)
        local radioactive = bodyContamination(self.character)
        local waterBefore = self.sink:getFluidAmount()
        local result = vanillaBodyComplete(self)
        if result and not isClient() and radioactive > ToxicConstants.SURFACE_TRACE then
            local consumed = math.max(0, waterBefore - self.sink:getFluidAmount())
            local water = math.max(0, additionalWater(radioactive) - consumed)
            local extraConsumed = 0
            if water > 0 then extraConsumed = tonumber(self.sink:useFluid(water)) or 0 end
            if extraConsumed > 0
                and not instanceof(self.sink, "IsoWorldInventoryObject") then
                self.sink:transmitModData()
            end
            local waterOk = consumed + extraConsumed + 0.0001 >= additionalWater(radioactive)
            local agentOk = waterOk
                and consumeAdditionalSoap(self.soaps, contaminationUses(radioactive))
            if waterOk and agentOk
                and type(ManualWashShared.onVanillaComplete) == "function" then
                ManualWashShared.onVanillaComplete(self.character, "body", nil)
            end
        end
        return result
    end
end

ManualWashShared.contamination = contamination
ManualWashShared.bodyContamination = bodyContamination
ManualWashShared.contaminationUses = contaminationUses
ManualWashShared.additionalWater = additionalWater
ManualWashShared.soapList = soapList
ManualWashShared.requiredBodyWater = function(character)
    return math.max(vanillaBodyWater(character), additionalWater(bodyContamination(character)))
end
ManualWashShared.requiredBodySoap = function(character)
    return vanillaBodySoap(character) + contaminationUses(bodyContamination(character))
end
ManualWashShared.isPatched = true

BunkerCampaignIntegration.ManualWashShared = ManualWashShared
return ManualWashShared
