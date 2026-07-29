require "ISUI/ISContextMenu"
require "BunkerCampaignIntegration/Constants"
require "BunkerCampaignIntegration/ManualWashClient"
require "BunkerCampaignIntegration/DecontaminationEffects"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local Constants = BunkerCampaignIntegration.Constants
local Rules = Constants.DECONTAMINATION
local Client = {
    status = nil,
    lastResult = nil,
}

local function send(player, command, args)
    if isClient() and player then
        sendClientCommand(player, Constants.DECON_NETWORK_MODULE, command, args or {})
    end
end

local function isAdministrator()
    if type(isAdmin) == "function" and isAdmin() then return true end
    return type(getAccessLevel) == "function" and getAccessLevel() == "admin"
end

local function inside(bounds, player)
    if not player or math.floor(player:getZ()) ~= bounds.z then return false end
    return player:getX() >= bounds.x1 and player:getX() <= bounds.x2
        and player:getY() >= bounds.y1 and player:getY() <= bounds.y2
end

local function notify(player, message)
    print("[BunkerCampaignDecontamination] " .. tostring(message))
    if player and HaloTextHelper then HaloTextHelper.addText(player, tostring(message)) end
end

local function onCreatePlayer(playerIndex, player)
    Client.status = nil
    if player then send(player, "requestStatus", {}) end
end

local function onServerCommand(module, command, args)
    if module ~= Constants.DECON_NETWORK_MODULE or type(args) ~= "table" then return end
    local player = getSpecificPlayer(0)
    if command == "deconStatus" then
        Client.status = args
    elseif command == "deconResult" then
        Client.lastResult = args
        if args.ok then
            notify(player, "Decontamination: " .. tostring(args.action) .. " accepted")
        else
            notify(player, "Decontamination: rejected (" .. tostring(args.code or "unknown_error") .. ")")
        end
    elseif command == "qaTeleport" then
        if args.nativeTeleport ~= true and player and type(args.x) == "number"
            and type(args.y) == "number" and type(args.z) == "number" then
            player:teleportTo(args.x, args.y, args.z)
        end
    end
end

local function addMode(menu, player, modeId, title)
    local mode = Rules.MODES[modeId]
    local label = string.format(
        "%s (%.0f L water%s)",
        title,
        mode.waterLiters,
        mode.requiresPower and ", power" or ""
    )
    menu:addOption(label, player, function(p)
        send(p, "startCycle", { mode=modeId })
    end)
end

local function addGameplayMenu(context, player)
    local root = context:addOption("Bunker Campaign: Decontamination")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)

    local status = Client.status
    if status then
        menu:addOption(string.format(
            "Status: %s | NBC %.0f%% | clean water %.1f L",
            tostring(status.status or "unknown"),
            tonumber(status.reagentUnits) or 0,
            tonumber(status.cleanWaterLiters) or 0
        ), player, function(p) send(p, "requestStatus", {}) end)
    else
        menu:addOption("Refresh status", player, function(p) send(p, "requestStatus", {}) end)
    end
    menu:addOption("Load NBC tablet into mixer (+50%)", player, function(p)
        send(p, "loadReagent", {})
    end)
    BunkerCampaignIntegration.ManualWashClient.addBunkerOptions(menu, player, status)
    addMode(menu, player, "emergency", "Emergency rinse")
    addMode(menu, player, "automatic", "Automatic full cycle")
end

local function addQaMenu(context, player)
    local root = context:addOption("Bunker Campaign: QA tools")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)

    local function teleport(title, target)
        menu:addOption(title, player, function(p) send(p, "qaTeleport", { target=target }) end)
    end

    teleport("[QA] Exterior toxic zone", "exterior")
    teleport("[QA] Dirty entrance", "dirty")
    teleport("[QA] Decontamination chamber", "chamber")
    teleport("[QA] Clean-side exit", "clean")
    teleport("[QA] NBC tablet locker", "reagent")
    menu:addOption("[QA] Set body and worn gear to 80%", player, function(p) send(p, "qaContaminate", {}) end)
    menu:addOption("[QA] Reset all carried contamination", player, function(p) send(p, "qaClean", {}) end)
    menu:addOption("[QA] Give tablets and cleaning agents", player, function(p) send(p, "qaGiveSupplies", {}) end)
    menu:addOption("[QA] Fill bunker water storage", player, function(p) send(p, "qaFillWater", {}) end)
    menu:addOption("[QA] Refuel main generator", player, function(p)
        send(p, "qaRefuelGenerator", { generator="main" })
    end)
    menu:addOption("[QA] Refuel backup generator", player, function(p)
        send(p, "qaRefuelGenerator", { generator="backup" })
    end)
    menu:addOption("[QA] Complete active cycle now", player, function(p) send(p, "qaFinishCycle", {}) end)
    menu:addOption("[QA] Create exterior test zone", player, function(p) send(p, "qaCreateZone", {}) end)
    menu:addOption("[QA] Remove exterior test zone", player, function(p) send(p, "qaRemoveZone", {}) end)
end

local function addContextOptions(playerNum, context, worldObjects, test)
    if test and ISWorldObjectContextMenu and ISWorldObjectContextMenu.Test then return true end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    if inside(Rules.INTERACTION, player) then addGameplayMenu(context, player) end
    if isAdministrator() then addQaMenu(context, player) end
end

local function draw()
    local player = getSpecificPlayer(0)
    local status = Client.status
    if not player or not status then return end
    local active = type(status.activeCycle) == "table"
    if active and not inside(Rules.ROOM, player) then return end
    if not active and not inside(Rules.INTERACTION, player) then return end

    local x = getCore():getScreenWidth() - 370
    local y = 50
    local cycleText = tostring(status.status or "idle")
    if active then
        cycleText = cycleText .. string.format(" (%.1f s)", tonumber(status.activeCycle.remainingSeconds) or 0)
    end
    getTextManager():DrawString(UIFont.Small, x, y, "DECONTAMINATION: " .. cycleText, 0.85, 0.95, 1.0, 0.95)
    getTextManager():DrawString(UIFont.Small, x, y + 18,
        string.format("NBC: %.0f%%   CLEAN WATER: %.1f L", tonumber(status.reagentUnits) or 0, tonumber(status.cleanWaterLiters) or 0),
        0.85, 0.95, 1.0, 0.95)
    getTextManager():DrawString(UIFont.Small, x, y + 36,
        string.format("BODY: %.1f%%   GEAR: %.1f%%", tonumber(status.surfaceContamination) or 0, tonumber(status.gearContamination) or 0),
        1.0, 0.75, 0.25, 0.95)
    if status.side == "clean" and status.unsafeForCleanSide then
        getTextManager():DrawString(UIFont.Small, x, y + 54, "WARNING: DIRTY LOAD ON CLEAN SIDE", 1.0, 0.15, 0.1, 1.0)
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnServerCommand.Add(onServerCommand)
Events.OnFillWorldObjectContextMenu.Add(addContextOptions)
Events.OnPreUIDraw.Add(draw)

BunkerCampaignIntegration.DecontaminationClient = Client
return Client
