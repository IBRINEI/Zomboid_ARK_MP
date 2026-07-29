require "BunkerCampaignToxicMP/Constants"

BunkerCampaignToxicMP = BunkerCampaignToxicMP or {}

local Constants = BunkerCampaignToxicMP.Constants
local Client = { status={inZone=false, exposure=0, protection=0}, alpha=0, geigerTicks=0, lastCommandResult=nil }
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

local function onCreatePlayer(playerIndex, player)
    Client.status = {inZone=false, exposure=0, protection=0}
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
    if Client.alpha <= 0 then return end
    UIManager.DrawTexture(overlay, 0, 0, getCore():getScreenWidth(), getCore():getScreenHeight(), Client.alpha)
    local exposure = math.floor(tonumber(Client.status.exposure) or 0)
    if exposure > 0 then
        getTextManager():DrawStringCentre(UIFont.Medium, getCore():getScreenWidth()/2, 55,
            "TOXIC EXPOSURE: " .. tostring(exposure) .. "%", 1, 0.25, 0.1, 0.95)
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnServerCommand.Add(onServerCommand)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnPreUIDraw.Add(draw)

BunkerCampaignToxicMP.Client = Client
return Client
