require "TimedActions/ISWashClothing"
require "TimedActions/ISWashYourself"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "ISUI/ISWorldObjectContextMenu"
require "BunkerCampaignIntegration/Constants"
require "BunkerCampaignIntegration/ManualWashActions"
require "BunkerCampaignToxicMP/Constants"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local IntegrationConstants = BunkerCampaignIntegration.Constants
local ToxicConstants = BunkerCampaignToxicMP.Constants
local ManualWashShared = BunkerCampaignIntegration.ManualWashShared
local ManualWashClient = {}

ISBunkerManualWash = ISBaseTimedAction:derive("ISBunkerManualWash")

local function inBunkerWashRange(player)
    if not player or player:isDead() then return false end
    local bounds = IntegrationConstants.DECONTAMINATION.INTERACTION
    local x, y, z = player:getX(), player:getY(), math.floor(player:getZ())
    return x >= bounds.x1 and x <= bounds.x2
        and y >= bounds.y1 and y <= bounds.y2 and z == bounds.z
end

function ISBunkerManualWash:isValid()
    if not inBunkerWashRange(self.character) then return false end
    if self.target == "item" then
        return self.item ~= nil and self.item:getContainer() ~= nil
            and ManualWashShared.contamination(self.item) > ToxicConstants.SURFACE_TRACE
    end
    return self.target == "body"
end

function ISBunkerManualWash:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Mid")
end

function ISBunkerManualWash:stop()
    ISBaseTimedAction.stop(self)
end

function ISBunkerManualWash:perform()
    sendClientCommand(self.character, IntegrationConstants.DECON_NETWORK_MODULE,
        "manualWashBunker", {
            target=self.target,
            itemId=self.item and self.item:getID() or nil,
            correlationId=self.correlationId,
        })
    ISBaseTimedAction.perform(self)
end

function ISBunkerManualWash:new(character, target, item, contamination)
    local action = ISBaseTimedAction.new(self, character)
    action.target = target
    action.item = item
    action.stopOnWalk = true
    action.stopOnRun = true
    action.maxTime = math.max(IntegrationConstants.DECONTAMINATION.MANUAL_WASH.minimumDuration,
        math.floor((tonumber(contamination) or 0) * 2))
    action.correlationId = "manual-wash:" .. tostring(character:getUsername()) .. ":"
        .. tostring(getTimestampMs()) .. ":" .. tostring(target) .. ":"
        .. tostring(item and item:getID() or "body")
    return action
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

local function queueVanillaItemWash(player, sink, item)
    if not luautils.walkAdjObject(player, sink, true, true) then return end
    local action = ISWashClothing:new(player, sink, item, 0, 0, false)
    action.soaps = ManualWashShared.soapList(player, true)
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
        if ManualWashShared.contamination(item) > ToxicConstants.SURFACE_TRACE then
            items[#items + 1] = item
        end
    end
    local body = ManualWashShared.bodyContamination(player)
    if #items == 0 and body <= ToxicConstants.SURFACE_TRACE then return end

    local root = context:addOption("Wash radioactive contamination")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    local availableSoap = ISWashClothing.GetSoapRemaining(ManualWashShared.soapList(player, true))

    if body > ToxicConstants.SURFACE_TRACE then
        local option = menu:addOption(string.format("Body (%.1f%%)", body), player,
            function(p) queueVanillaBodyWash(p, sink) end)
        option.notAvailable = sink:getFluidAmount() < ManualWashShared.requiredBodyWater(player)
            or availableSoap < ManualWashShared.requiredBodySoap(player)
    end
    for _, item in ipairs(items) do
        local value = ManualWashShared.contamination(item)
        local option = menu:addOption(string.format("%s (%.1f%%)", item:getName(), value), player,
            function(p) queueVanillaItemWash(p, sink, item) end)
        option.itemForTexture = item
        option.notAvailable = sink:getFluidAmount() < ISWashClothing.GetRequiredWater(item)
            or availableSoap < ISWashClothing.GetRequiredSoap(item)
    end
end

local function queueBunkerWash(player, target, item, contamination)
    if not player or not isClient() or not inBunkerWashRange(player) then return end
    ISTimedActionQueue.add(ISBunkerManualWash:new(player, target, item, contamination))
end

function ManualWashClient.addBunkerOptions(menu, player, status)
    local root = menu:addOption("Manual radioactive wash (bunker water)")
    local washMenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(root, washMenu)
    local body = tonumber(status and status.surfaceContamination) or 0
    local added = 0
    if body > ToxicConstants.SURFACE_TRACE then
        washMenu:addOption(string.format("Body (%.1f%%, %d L, %d agent uses)",
            body, ManualWashShared.additionalWater(body), ManualWashShared.contaminationUses(body)),
            player, function(p) queueBunkerWash(p, "body", nil, body) end)
        added = added + 1
    end
    for _, item in ipairs(collectCarriedItems(player, ToxicConstants.MAX_CARRIED_ITEMS_PER_SCAN)) do
        local value = ManualWashShared.contamination(item)
        if value > ToxicConstants.SURFACE_TRACE then
            local option = washMenu:addOption(string.format("%s (%.1f%%, %d L, %d agent uses)",
                item:getName(), value, ManualWashShared.additionalWater(value),
                ManualWashShared.contaminationUses(value)), player,
                function(p) queueBunkerWash(p, "item", item, value) end)
            option.itemForTexture = item
            added = added + 1
        end
    end
    if added == 0 then root.notAvailable = true end
end

Events.OnFillWorldObjectContextMenu.Add(addExternalWaterMenu)

BunkerCampaignIntegration.ManualWashClient = ManualWashClient
return ManualWashClient
