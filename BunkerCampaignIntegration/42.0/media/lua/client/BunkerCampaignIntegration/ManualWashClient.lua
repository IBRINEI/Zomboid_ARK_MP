require "TimedActions/ISWashClothing"
require "TimedActions/ISWashYourself"
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

local function requestBunkerWash(player, target, item)
    if not player or not isClient() then return end
    sendClientCommand(player, IntegrationConstants.DECON_NETWORK_MODULE, "manualWashBunker", {
        target=target,
        itemId=item and item:getID() or nil,
    })
end

function ManualWashClient.addBunkerOptions(menu, player, status)
    local root = menu:addOption("Manual radioactive wash (bunker water, instant)")
    local washMenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(root, washMenu)
    local body = tonumber(status and status.surfaceContamination) or 0
    local added = 0
    if body > ToxicConstants.SURFACE_TRACE then
        washMenu:addOption(string.format("Body (%.1f%%, %d L, %d agent uses)",
            body, ManualWashShared.additionalWater(body), ManualWashShared.contaminationUses(body)),
            player, function(p) requestBunkerWash(p, "body", nil) end)
        added = added + 1
    end
    for _, item in ipairs(collectCarriedItems(player, ToxicConstants.MAX_CARRIED_ITEMS_PER_SCAN)) do
        local value = ManualWashShared.contamination(item)
        if value > ToxicConstants.SURFACE_TRACE then
            local option = washMenu:addOption(string.format("%s (%.1f%%, %d L, %d agent uses)",
                item:getName(), value, ManualWashShared.additionalWater(value),
                ManualWashShared.contaminationUses(value)), player,
                function(p) requestBunkerWash(p, "item", item) end)
            option.itemForTexture = item
            added = added + 1
        end
    end
    if added == 0 then root.notAvailable = true end
end

Events.OnFillWorldObjectContextMenu.Add(addExternalWaterMenu)

BunkerCampaignIntegration.ManualWashClient = ManualWashClient
return ManualWashClient
