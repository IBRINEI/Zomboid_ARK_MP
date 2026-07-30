require "TimedActions/ISBaseTimedAction"
require "BunkerCampaignIntegration/Constants"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local Constants = BunkerCampaignIntegration.Constants
local Rules = Constants.DECONTAMINATION

local function sendVanillaCommand(character, sink, command, target, item)
    if not isClient() or not character then return end
    local square = sink and sink:getSquare() or nil
    sendClientCommand(character, Constants.DECON_NETWORK_MODULE, command, {
        target=target,
        itemId=item and item:getID() or nil,
        sourceX=square and square:getX() or nil,
        sourceY=square and square:getY() or nil,
        sourceZ=square and square:getZ() or nil,
    })
end

ISRadioactiveWashBegin = ISBaseTimedAction:derive("ISRadioactiveWashBegin")

function ISRadioactiveWashBegin:isValid()
    return self.character and not self.character:isDead()
end

function ISRadioactiveWashBegin:complete()
    sendVanillaCommand(self.character, self.sink, "manualWashVanillaStart", self.target, self.item)
    return true
end

function ISRadioactiveWashBegin:perform()
    ISBaseTimedAction.perform(self)
end

function ISRadioactiveWashBegin:new(character, sink, target, item)
    local action = ISBaseTimedAction.new(self, character)
    action.sink = sink
    action.target = target
    action.item = item
    action.maxTime = 1
    return action
end

ISRadioactiveWashFinalize = ISBaseTimedAction:derive("ISRadioactiveWashFinalize")

function ISRadioactiveWashFinalize:isValid()
    return self.character and not self.character:isDead()
end

function ISRadioactiveWashFinalize:complete()
    sendVanillaCommand(self.character, self.sink, "manualWashVanilla", self.target, self.item)
    return true
end

function ISRadioactiveWashFinalize:perform()
    ISBaseTimedAction.perform(self)
end

function ISRadioactiveWashFinalize:new(character, sink, target, item)
    local action = ISBaseTimedAction.new(self, character)
    action.sink = sink
    action.target = target
    action.item = item
    action.maxTime = 1
    return action
end

ISBunkerManualWash = ISBaseTimedAction:derive("ISBunkerManualWash")

function ISBunkerManualWash:isValid()
    return self.character and not self.character:isDead()
end

function ISBunkerManualWash:start()
    self.startedAt = getTimestampMs()
    if self.target == "body" then
        self:setActionAnim("WashFace")
        self:setOverrideHandModels(nil, nil)
    else
        self:setActionAnim("ScrubClothWithSoap")
        self:setOverrideHandModels(getScriptManager():FindItem("Soap2"):getStaticModel(),
            getScriptManager():FindItem("DishCloth"):getStaticModel())
        if self.item then self.item:setJobDelta(0) end
    end
    self.character:reportEvent("EventWashClothing")
end

function ISBunkerManualWash:update()
    if self.item then self.item:setJobDelta(self:getJobDelta()) end
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
    local timedOut = self.startedAt and getTimestampMs() - self.startedAt >= 15000
    if not self.forcedCompletion and (self:getJobDelta() >= 0.99 or timedOut) then
        self.forcedCompletion = true
        self:forceComplete()
    end
end

function ISBunkerManualWash:stop()
    if self.item then self.item:setJobDelta(0) end
    self.character:resetModel()
    self.character:resetModelNextFrame()
    ISBaseTimedAction.stop(self)
end

function ISBunkerManualWash:complete()
    if isClient() then
        sendClientCommand(self.character, Constants.DECON_NETWORK_MODULE, "manualWashBunker", {
            target=self.target,
            itemId=self.item and self.item:getID() or nil,
        })
    end
    return true
end

function ISBunkerManualWash:perform()
    if self.item then self.item:setJobDelta(0) end
    self.character:resetModel()
    self.character:resetModelNextFrame()
    ISBaseTimedAction.perform(self)
end

function ISBunkerManualWash:new(character, target, item, value)
    local action = ISBaseTimedAction.new(self, character)
    action.character = character
    action.target = target
    action.item = item
    action.stopOnWalk = true
    action.stopOnRun = true
    action.forceProgressBar = true
    action.maxTime = math.max(Rules.MANUAL_WASH.minimumDuration, math.floor((tonumber(value) or 0) * 3))
    return action
end

local ManualWashActions = {
    ISRadioactiveWashBegin=ISRadioactiveWashBegin,
    ISRadioactiveWashFinalize=ISRadioactiveWashFinalize,
    ISBunkerManualWash=ISBunkerManualWash,
}

BunkerCampaignIntegration.ManualWashActions = ManualWashActions
return ManualWashActions
