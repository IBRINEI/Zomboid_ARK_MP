require "TimedActions/ISBaseTimedAction"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local RepairIntakeAction = ISBaseTimedAction:derive("BunkerCampaignRepairIntakeAction")

function RepairIntakeAction:isValid()
    return self.character and not self.character:isDead()
        and self.scrap and self.scrap:getContainer() ~= nil
end

function RepairIntakeAction:waitToStart()
    self.character:faceLocation(self.x, self.y)
    return self.character:shouldBeTurning()
end

function RepairIntakeAction:update()
    self.character:faceLocation(self.x, self.y)
    self.character:setMetabolicTarget(Metabolics.MediumWork)
end

function RepairIntakeAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
    self:setOverrideHandModels(self.scrap, nil)
end

function RepairIntakeAction:stop()
    ISBaseTimedAction.stop(self)
end

function RepairIntakeAction:perform()
    ISBaseTimedAction.perform(self)
end

function RepairIntakeAction:complete()
    sendClientCommand(self.character, "BunkerCampaignDecontamination", "repairIntake", {
        x=self.x, y=self.y, z=self.z,
    })
    return true
end

function RepairIntakeAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 250
end

function RepairIntakeAction:new(character, scrap, x, y, z)
    local action = ISBaseTimedAction.new(self, character)
    action.scrap = scrap
    action.x = x
    action.y = y
    action.z = z
    action.maxTime = action:getDuration()
    return action
end

BunkerCampaignIntegration.RepairIntakeAction = RepairIntakeAction
return RepairIntakeAction
