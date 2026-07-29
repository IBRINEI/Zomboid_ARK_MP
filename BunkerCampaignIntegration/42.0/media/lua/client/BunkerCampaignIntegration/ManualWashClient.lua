require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISWashClothing"
require "TimedActions/ISWashYourself"
require "TimedActions/ISTimedActionQueue"
require "ISUI/ISWorldObjectContextMenu"
require "BunkerCampaignIntegration/Constants"
require "BunkerCampaignToxicMP/Constants"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local IntegrationConstants = BunkerCampaignIntegration.Constants
local ToxicConstants = BunkerCampaignToxicMP.Constants
local Rules = IntegrationConstants.DECONTAMINATION
local ManualWashClient = {}

local function contamination(item)
    if not item or not item.getModData then return 0 end
    return math.max(0, math.min(100,
        tonumber(item:getModData()[ToxicConstants.CONTAMINATION_MODDATA_KEY]) or 0))
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
    return math.max(0.001, tonumber(ZomboidGlobals and ZomboidGlobals.CleanStainCleaningFluidAmount) or 0.1)
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

local function sendVanillaCompletion(character, sink, target, item)
    if not isClient() or not character then return end
    local square = sink and sink:getSquare() or nil
    sendClientCommand(character, IntegrationConstants.DECON_NETWORK_MODULE, "manualWashVanilla", {
        target=target,
        itemId=item and item:getID() or nil,
        sourceX=square and square:getX() or nil,
        sourceY=square and square:getY() or nil,
        sourceZ=square and square:getZ() or nil,
    })
end

local function sendVanillaStart(character, sink, target, item)
    if not isClient() or not character then return end
    local square = sink and sink:getSquare() or nil
    sendClientCommand(character, IntegrationConstants.DECON_NETWORK_MODULE, "manualWashVanillaStart", {
        target=target,
        itemId=item and item:getID() or nil,
        sourceX=square and square:getX() or nil,
        sourceY=square and square:getY() or nil,
        sourceZ=square and square:getZ() or nil,
    })
end

if not BunkerCampaignIntegration.ManualWashPatched then
    BunkerCampaignIntegration.ManualWashPatched = true

    local vanillaClothingSoap = ISWashClothing.GetRequiredSoap
    local vanillaClothingWater = ISWashClothing.GetRequiredWater
    local vanillaSoapRemaining = ISWashClothing.GetSoapRemaining
    local vanillaClothingNew = ISWashClothing.new
    local vanillaClothingStart = ISWashClothing.start
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
        action.soaps = addBleachToSoapList(character, action.soaps)
        return action
    end

    ISWashClothing.complete = function(self)
        local radioactive = contamination(self.item)
        local result = vanillaClothingComplete(self)
        if result and radioactive > ToxicConstants.SURFACE_TRACE then
            consumeAdditionalSoap(self.soaps, contaminationUses(radioactive))
            sendVanillaCompletion(self.character, self.sink, "item", self.item)
        end
        return result
    end


    ISWashClothing.start = function(self)
        vanillaClothingStart(self)
        if contamination(self.item) > ToxicConstants.SURFACE_TRACE then
            sendVanillaStart(self.character, self.sink, "item", self.item)
        end
    end

    local vanillaBodySoap = ISWashYourself.GetRequiredSoap
    local vanillaBodyWater = ISWashYourself.GetRequiredWater
    local vanillaBodyNew = ISWashYourself.new
    local vanillaBodyStart = ISWashYourself.start
    local vanillaBodyComplete = ISWashYourself.complete

    ISWashYourself.GetRequiredSoap = function(character)
        local status = BunkerCampaignToxicMP.Client and BunkerCampaignToxicMP.Client.status
        local radioactive = tonumber(status and status.surfaceContamination) or 0
        return vanillaBodySoap(character) + contaminationUses(radioactive)
    end

    ISWashYourself.GetRequiredWater = function(character)
        local status = BunkerCampaignToxicMP.Client and BunkerCampaignToxicMP.Client.status
        local radioactive = tonumber(status and status.surfaceContamination) or 0
        return math.max(vanillaBodyWater(character), additionalWater(radioactive))
    end

    ISWashYourself.new = function(self, character, sink)
        local action = vanillaBodyNew(self, character, sink)
        action.soaps = addBleachToSoapList(character, action.soaps)
        return action
    end

    ISWashYourself.complete = function(self)
        local status = BunkerCampaignToxicMP.Client and BunkerCampaignToxicMP.Client.status
        local radioactive = tonumber(status and status.surfaceContamination) or 0
        local waterBefore = self.sink:getFluidAmount()
        local result = vanillaBodyComplete(self)
        if result and radioactive > ToxicConstants.SURFACE_TRACE then
            local consumed = math.max(0, waterBefore - self.sink:getFluidAmount())
            local water = math.max(0, additionalWater(radioactive) - consumed)
            if water > 0 and self.sink:useFluid(water) > 0
                and not instanceof(self.sink, "IsoWorldInventoryObject") then
                self.sink:transmitModData()
            end
            consumeAdditionalSoap(self.soaps, contaminationUses(radioactive))
            sendVanillaCompletion(self.character, self.sink, "body", nil)
        end
        return result
    end


    ISWashYourself.start = function(self)
        vanillaBodyStart(self)
        local status = BunkerCampaignToxicMP.Client and BunkerCampaignToxicMP.Client.status
        if (tonumber(status and status.surfaceContamination) or 0) > ToxicConstants.SURFACE_TRACE then
            sendVanillaStart(self.character, self.sink, "body", nil)
        end
    end
end

local function collectCarriedItems(player, limit)
    local result = {}
    local containers = { player:getInventory() }
    local containerIndex = 1
    while containerIndex <= #containers and #result < limit do
        local container = containers[containerIndex]
        containerIndex = containerIndex + 1
        local items = container:getItems()
        for index = 0, items:size() - 1 do
            if #result >= limit then break end
            local item = items:get(index)
            if item then
                result[#result + 1] = item
                if instanceof(item, "InventoryContainer")
                    and item:getModData().BunkerCampaignSealed ~= true then
                    containers[#containers + 1] = item:getInventory()
                end
            end
        end
    end
    return result
end

local function findWaterSource(worldObjects)
    for _, object in ipairs(worldObjects or {}) do
        local ok, amount = pcall(function() return object:getFluidAmount() end)
        if ok and tonumber(amount) and amount > 0 then return object end
    end
    return nil
end

local function soapList(player)
    return addBleachToSoapList(player, player:getInventory():getSoapList(nil, true))
end

local function queueVanillaItemWash(player, sink, item)
    if not luautils.walkAdjObject(player, sink, true, true) then return end
    local action = ISWashClothing:new(player, sink, item, 0, 0, false)
    action.soaps = soapList(player)
    ISTimedActionQueue.add(action)
end

local function queueVanillaBodyWash(player, sink)
    if not luautils.walkAdjObject(player, sink, true, true) then return end
    ISTimedActionQueue.add(ISWashYourself:new(player, sink))
end

local function addExternalWaterMenu(playerNum, context, worldObjects, test)
    if test and ISWorldObjectContextMenu and ISWorldObjectContextMenu.Test then return true end
    local player = getSpecificPlayer(playerNum)
    local sink = player and findWaterSource(worldObjects) or nil
    if not player or not sink then return end

    local items = {}
    for _, item in ipairs(collectCarriedItems(player, ToxicConstants.MAX_CARRIED_ITEMS_PER_SCAN)) do
        if contamination(item) > ToxicConstants.SURFACE_TRACE then items[#items + 1] = item end
    end
    local toxicStatus = BunkerCampaignToxicMP.Client and BunkerCampaignToxicMP.Client.status
    local body = tonumber(toxicStatus and toxicStatus.surfaceContamination) or 0
    if #items == 0 and body <= ToxicConstants.SURFACE_TRACE then return end

    local root = context:addOption("Wash radioactive contamination")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    local availableSoap = ISWashClothing.GetSoapRemaining(soapList(player))

    if body > ToxicConstants.SURFACE_TRACE then
        local option = menu:addOption(string.format("Body (%.1f%%)", body), player,
            function(p) queueVanillaBodyWash(p, sink) end)
        option.notAvailable = sink:getFluidAmount() < additionalWater(body)
            or availableSoap < ISWashYourself.GetRequiredSoap(player)
    end
    for _, item in ipairs(items) do
        local value = contamination(item)
        local option = menu:addOption(string.format("%s (%.1f%%)", item:getName(), value), player,
            function(p) queueVanillaItemWash(p, sink, item) end)
        option.itemForTexture = item
        option.notAvailable = sink:getFluidAmount() < ISWashClothing.GetRequiredWater(item)
            or availableSoap < ISWashClothing.GetRequiredSoap(item)
    end
end

ISBunkerManualWash = ISBaseTimedAction:derive("ISBunkerManualWash")

function ISBunkerManualWash:isValid()
    return self.character and not self.character:isDead()
end

function ISBunkerManualWash:start()
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
end

function ISBunkerManualWash:stop()
    if self.item then self.item:setJobDelta(0) end
    self.character:resetModelNextFrame()
    ISBaseTimedAction.stop(self)
end

function ISBunkerManualWash:complete()
    sendClientCommand(self.character, IntegrationConstants.DECON_NETWORK_MODULE, "manualWashBunker", {
        target=self.target,
        itemId=self.item and self.item:getID() or nil,
    })
    return true
end

function ISBunkerManualWash:perform()
    if self.item then self.item:setJobDelta(0) end
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

function ManualWashClient.addBunkerOptions(menu, player, status)
    local root = menu:addOption("Manual radioactive wash (bunker water)")
    local washMenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(root, washMenu)
    local body = tonumber(status and status.surfaceContamination) or 0
    local added = 0
    if body > ToxicConstants.SURFACE_TRACE then
        washMenu:addOption(string.format("Body (%.1f%%, %d L, %d agent uses)",
            body, additionalWater(body), contaminationUses(body)), player, function(p)
            ISTimedActionQueue.add(ISBunkerManualWash:new(p, "body", nil, body))
        end)
        added = added + 1
    end
    for _, item in ipairs(collectCarriedItems(player, ToxicConstants.MAX_CARRIED_ITEMS_PER_SCAN)) do
        local value = contamination(item)
        if value > ToxicConstants.SURFACE_TRACE then
            local option = washMenu:addOption(string.format("%s (%.1f%%, %d L, %d agent uses)",
                item:getName(), value, additionalWater(value), contaminationUses(value)), player,
                function(p) ISTimedActionQueue.add(ISBunkerManualWash:new(p, "item", item, value)) end)
            option.itemForTexture = item
            added = added + 1
        end
    end
    if added == 0 then root.notAvailable = true end
end

Events.OnFillWorldObjectContextMenu.Add(addExternalWaterMenu)

BunkerCampaignIntegration.ManualWashClient = ManualWashClient
return ManualWashClient
