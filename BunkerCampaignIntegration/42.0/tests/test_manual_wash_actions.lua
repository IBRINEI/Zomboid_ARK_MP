local Shared = BunkerCampaignIntegration.ManualWashShared

assert(type(Shared) == "table" and Shared.isPatched == true,
    "shared vanilla wash integration must be installed")
assert(ISRadioactiveWashBegin == nil and ISRadioactiveWashFinalize == nil
    and ISBunkerManualWash == nil,
    "manual washing must not depend on custom Build 42 timed actions")
assert(type(ISWashClothing.complete) == "function"
    and type(ISWashYourself.complete) == "function",
    "vanilla wash completion hooks must remain callable")
assert(Shared.additionalWater(50) == 9 and Shared.contaminationUses(50) == 2,
    "shared manual wash resource calculations must remain stable")

isClient = function() return false end
Math = { ceil=math.ceil }
syncItemFields = function() end
syncVisuals = function() end
sendHumanVisual = function() end
ItemBodyLocation = {
    MAKE_UP_FULL_FACE="full", MAKE_UP_EYES="eyes",
    MAKE_UP_EYES_SHADOW="shadow", MAKE_UP_LIPS="lips",
}
BloodBodyPartType = {
    MAX={index=function() return 0 end},
    FromIndex=function() return nil end,
}

local itemData = { BunkerCampaignSurfaceContamination=50 }
local item = {
    getModData=function() return itemData end,
    getBloodLevel=function() return 0 end,
    getItemAfterCleaning=function() return nil end,
    setBloodLevel=function() end,
}
local character = {
    updateHandEquips=function() end,
    isPrimaryHandItem=function() return false end,
    isSecondaryHandItem=function() return false end,
    getHumanVisual=function() return {} end,
    getWornItem=function() return nil end,
}
local sinkUsed = 0
local sink = {
    getFluidAmount=function() return 100 - sinkUsed end,
    useFluid=function(self, amount) sinkUsed = sinkUsed + amount; return amount end,
    transmitModData=function() end,
}
local soapUses = 2
local soap = {
    getCurrentUses=function() return soapUses end,
    UseAndSync=function() soapUses = soapUses - 1 end,
}
instanceof = function(object, className)
    return object == soap and className == "DrainableComboItem"
end
local soapList = {
    size=function() return 1 end,
    get=function() return soap end,
}
local completedTarget = nil
Shared.onVanillaComplete = function(_, target) completedTarget = target; return true end

local clothingAction = setmetatable({
    character=character, sink=sink, item=item, soaps=soapList, noSoap=false,
}, {__index=ISWashClothing})
assert(clothingAction:complete() == true and completedTarget == "item",
    "server completion of the vanilla clothing action must invoke radioactive cleaning")
assert(sinkUsed == 9,
    "the vanilla clothing action must debit the full radioactive water requirement")

sinkUsed = 0
soapUses = 2
completedTarget = nil
Shared.getBodyContamination = function() return 50 end
assert(Shared.requiredBodyWater(character) == 9
    and Shared.requiredBodySoap(character) == 2,
    "client availability checks must include radioactive body resources")
local bodyAction = setmetatable({
    character=character, sink=sink, soaps=soapList,
}, {__index=ISWashYourself})
assert(bodyAction:complete() == true and completedTarget == "body",
    "server completion of the vanilla body action must invoke radioactive cleaning")
assert(sinkUsed == 9,
    "the vanilla body action must debit the full radioactive water requirement")

print("BunkerCampaign shared vanilla wash integration tests passed")
