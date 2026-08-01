require "TimedActions/ISBaseTimedAction"
require "BunkerCampaign/HeatingComponents"
require "BunkerCampaign/ClientState"

BunkerCampaign = BunkerCampaign or {}

local HeatingComponents = BunkerCampaign.HeatingComponents
local ClientState = BunkerCampaign.ClientState
local HeatingComponentAction = ISBaseTimedAction:derive("BunkerCampaignHeatingComponentAction")

function HeatingComponentAction:isValid()
    return self.character and not self.character:isDead()
        and self.object and HeatingComponents.matchObject(self.object) ~= nil
end

function HeatingComponentAction:waitToStart()
    local definition = HeatingComponents.get(self.componentId)
    self.character:faceLocation(definition.x, definition.y)
    return self.character:shouldBeTurning()
end

function HeatingComponentAction:update()
    local definition = HeatingComponents.get(self.componentId)
    self.character:faceLocation(definition.x, definition.y)
    self.character:setMetabolicTarget(Metabolics.MediumWork)
end

function HeatingComponentAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function HeatingComponentAction:perform()
    if self.actionKind == "diagnose" then
        ClientState.diagnoseHeatingComponent(self.character, self.componentId)
    elseif self.actionKind == "temporary" or self.actionKind == "full" then
        ClientState.repairHeatingComponent(self.character, self.componentId, self.actionKind)
    elseif self.actionKind == "valve" then
        ClientState.setHeatingValve(self.character, self.componentId, self.value == true)
    elseif self.actionKind == "bypass" then
        ClientState.setHeatingManualBypass(self.character, self.value == true)
    end
    ISBaseTimedAction.perform(self)
end

function HeatingComponentAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    if self.actionKind == "diagnose" then return 180 end
    if self.actionKind == "temporary" then return 300 end
    if self.actionKind == "full" then return 600 end
    return 100
end

function HeatingComponentAction:new(character, object, componentId, actionKind, value)
    local action = ISBaseTimedAction.new(self, character)
    action.object = object
    action.componentId = componentId
    action.actionKind = actionKind
    action.value = value
    action.maxTime = action:getDuration()
    action.stopOnWalk = true
    action.stopOnRun = true
    return action
end

BunkerCampaign.HeatingComponentAction = HeatingComponentAction
return HeatingComponentAction
