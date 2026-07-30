require "BunkerCampaignToxicMP/Constants"

BunkerCampaignToxicMP = BunkerCampaignToxicMP or {}

local Constants = BunkerCampaignToxicMP.Constants
local Client = { status={inZone=false, exposure=0, protection=0, surfaceContamination=0, gearContamination=0}, alpha=0, geigerTicks=0, lastCommandResult=nil }
local overlay = getTexture("media/textures/UI/ToxicOverlay.png")

local function containsPattern(value, patterns)
    value = string.lower(value or "")
    for _, pattern in ipairs(patterns) do
        if string.find(value, pattern, 1, true) then return true end
    end
    return false
end

local function setVisibleFilterCondition(item, remaining)
    if not item or not item.getConditionMax or not item.setCondition then return end
    local maximum = tonumber(item:getConditionMax()) or 0
    if maximum > 0 then
        local condition = remaining <= 0 and 0 or math.max(1, math.floor(maximum * remaining))
        item:setCondition(condition)
    end
end

local function applyFilterRemaining(player, value, itemId)
    value = tonumber(value)
    if not player or not value then return end
    value = math.max(0, math.min(1, value))
    local item = nil
    local inventory = player:getInventory()
    if itemId ~= nil and inventory and inventory.getItemWithID then
        item = inventory:getItemWithID(itemId)
    end
    local worn = player:getWornItems()
    if not item then
        for index = 0, worn:size() - 1 do
            local candidate = worn:getItemByIndex(index)
            local itemType = candidate and candidate:getType() or nil
            if candidate and (Constants.PROTECTIVE_MASKS[itemType]
                or containsPattern(itemType, Constants.GAS_MASK_PATTERNS)) then
                item = candidate
                break
            end
        end
    end
    if not item then return end

    item:getModData().percent = value
    setVisibleFilterCondition(item, value)
end

local function cleanLocalItem(item, removalFraction)
    if not item or not item.getModData then return end
    local data = item:getModData()
    local current = math.max(0, math.min(100,
        tonumber(data[Constants.CONTAMINATION_MODDATA_KEY]) or 0))
    data[Constants.CONTAMINATION_MODDATA_KEY] = current
        * (1 - math.max(0, math.min(1, tonumber(removalFraction) or 0)))
end

local function visitContainer(container, callback, limit)
    if not container or not container.getItems then return 0 end
    local containers = { container }
    local containerIndex = 1
    local visited = 0
    while containerIndex <= #containers and visited < limit do
        local current = containers[containerIndex]
        containerIndex = containerIndex + 1
        local items = current:getItems()
        for index = 0, items:size() - 1 do
            if visited >= limit then break end
            local item = items:get(index)
            if item then
                visited = visited + 1
                callback(item)
                if instanceof(item, "InventoryContainer")
                    and item:getModData().BunkerCampaignSealed ~= true then
                    containers[#containers + 1] = item:getInventory()
                end
            end
        end
    end
    return visited
end

local function applyCarriedItemContamination(args)
    local player = getSpecificPlayer(0)
    local itemId = tonumber(args.itemId)
    if not player or not itemId then return end
    visitContainer(player:getInventory(), function(item)
        if item:getID() == itemId then
            item:getModData()[Constants.CONTAMINATION_MODDATA_KEY] = math.max(0,
                math.min(100, tonumber(args.value) or 0))
        end
    end, Constants.MAX_CARRIED_ITEMS_PER_SCAN)
end

local function applyWorldCleanup(args)
    local cell = getCell()
    if not cell then return end
    local x1, x2 = math.ceil(tonumber(args.x1) or 0), math.floor(tonumber(args.x2) or -1)
    local y1, y2 = math.ceil(tonumber(args.y1) or 0), math.floor(tonumber(args.y2) or -1)
    local z = tonumber(args.z) or 0
    local removalFraction = tonumber(args.removalFraction) or 0
    local remaining = Constants.MAX_WORLD_ITEMS_PER_CYCLE
    for x = x1, x2 do
        for y = y1, y2 do
            if remaining <= 0 then break end
            local square = cell:getGridSquare(x, y, z)
            if square then
                local worldObjects = square:getWorldObjects()
                if worldObjects then
                    for index = 0, worldObjects:size() - 1 do
                        if remaining <= 0 then break end
                        local object = worldObjects:get(index)
                        local item = object and instanceof(object, "IsoWorldInventoryObject")
                            and object:getItem() or nil
                        if item then
                            cleanLocalItem(item, removalFraction)
                            remaining = remaining - 1
                            if instanceof(item, "InventoryContainer") then
                                remaining = remaining - visitContainer(item:getInventory(), function(nested)
                                    cleanLocalItem(nested, removalFraction)
                                end, remaining)
                            end
                        end
                    end
                end
                local staticObjects = square:getStaticMovingObjects()
                if staticObjects then
                    for index = 0, staticObjects:size() - 1 do
                        if remaining <= 0 then break end
                        local object = staticObjects:get(index)
                        if object and instanceof(object, "IsoDeadBody") then
                            cleanLocalItem(object, removalFraction)
                            remaining = remaining - visitContainer(object:getContainer(), function(item)
                                cleanLocalItem(item, removalFraction)
                            end, remaining)
                        end
                    end
                end
            end
        end
        if remaining <= 0 then break end
    end
end

local function onCreatePlayer(playerIndex, player)
    Client.status = {inZone=false, exposure=0, protection=0, surfaceContamination=0, gearContamination=0}
    Client.alpha = 0
    if isClient() and player then
        ModData.request(Constants.ZONES_KEY)
        sendClientCommand(player, Constants.NETWORK_MODULE, "requestStatus", {})
    end
end

local function onServerCommand(module, command, args)
    if module ~= Constants.NETWORK_MODULE or type(args) ~= "table" then return end
    if command == "exposureStatus" then
        Client.status = args
        applyFilterRemaining(getSpecificPlayer(0), args.filterRemaining, args.filterItemId)
    elseif command == "itemContamination" then
        applyCarriedItemContamination(args)
    elseif command == "worldContaminationCleaned" then
        applyWorldCleanup(args)
    elseif command == "zoneCommandResult" then
        Client.lastCommandResult = args
        local player = getSpecificPlayer(0)
        local message
        if args.ok then
            message = "Toxic Zones: " .. tostring(args.action) .. " complete; zones: " .. tostring(args.zoneCount or 0)
        else
            message = "Toxic Zones: rejected (" .. tostring(args.code or "unknown_error") .. ")"
        end
        print("[BunkerCampaignToxicMP] " .. message)
        if player and HaloTextHelper then HaloTextHelper.addText(player, message) end
    end
end

local function onPlayerUpdate(player)
    if not player or player:getPlayerNum() ~= 0 then return end
    Client.geigerTicks = Client.geigerTicks + 1
    if Client.status.inZone and Client.geigerTicks >= 180 then
        Client.geigerTicks = 0
        if player:getInventory():contains("Base.ContaminantDetector", false, false) then
            local sounds = {"GeigerCounter", "GeigerCounter2", "GeigerCounter3", "GeigerCounter4"}
            player:playSound(sounds[1 + ZombRand(#sounds)])
        end
    end
end

local function draw()
    if Client.status.inZone then Client.alpha = math.min(0.6, Client.alpha + 0.04)
    else Client.alpha = math.max(0, Client.alpha - 0.04) end
    if Client.alpha > 0 then
        UIManager.DrawTexture(overlay, 0, 0, getCore():getScreenWidth(), getCore():getScreenHeight(), Client.alpha)
    end
    local exposure = math.floor(tonumber(Client.status.exposure) or 0)
    local surface = tonumber(Client.status.surfaceContamination) or 0
    local gear = tonumber(Client.status.gearContamination) or 0
    if exposure > 0 then
        getTextManager():DrawStringCentre(UIFont.Medium, getCore():getScreenWidth()/2, 55,
            "TOXIC EXPOSURE: " .. tostring(exposure) .. "%", 1, 0.25, 0.1, 0.95)
    end
    if surface > Constants.SURFACE_TRACE or gear > Constants.SURFACE_TRACE then
        getTextManager():DrawStringCentre(UIFont.Medium, getCore():getScreenWidth()/2, 78,
            string.format("SURFACE: %.1f%%   GEAR: %.1f%%", surface, gear), 1, 0.65, 0.1, 0.95)
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnServerCommand.Add(onServerCommand)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnPreUIDraw.Add(draw)

BunkerCampaignToxicMP.Client = Client
return Client
