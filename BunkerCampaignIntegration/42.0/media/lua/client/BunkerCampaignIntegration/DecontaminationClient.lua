require "ISUI/ISContextMenu"
require "ISUI/ISModalRichText"
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

local function showQaReport(args)
    local kind = tostring(args.kind or "all")
    local lines = { "<H1> Bunker Campaign QA report <LINE><LINE>" }
    if kind ~= "water" then
        local entry = args.entryPath or {}
        local airlock = args.airlock or {}
        lines[#lines + 1] = string.format(
            "<H2> Atmosphere <LINE><TEXT> Room: %s | CO2 %.0f ppm | air %.2f%% | occupants %d <LINE>",
            tostring(args.roomId or "outside"), tonumber(args.roomCo2) or 0,
            (tonumber(args.roomContamination) or 0) * 100, tonumber(args.roomOccupants) or 0)
        lines[#lines + 1] = string.format(
            "Vent filter: %.2f%% | use %.4f%%/min | activity %s <LINE>",
            (tonumber(args.filterRemaining) or 0) * 100,
            (tonumber(args.filterUsePerMinute) or 0) * 100,
            tostring(args.filterActivity or "unknown"))
        lines[#lines + 1] = string.format("Entry: %s | %d/%d open, %d/%d loaded <LINE>",
            entry.breached and "BREACHED" or "contained", tonumber(entry.openCount) or 0,
            tonumber(entry.total) or 0, tonumber(entry.loadedCount) or 0, tonumber(entry.total) or 0)
        for _, door in ipairs(type(entry.doors) == "table" and entry.doors or {}) do
            lines[#lines + 1] = string.format("%s (%d,%d,Z%d): %s <LINE>",
                tostring(door.label or door.id), tonumber(door.x) or 0, tonumber(door.y) or 0,
                tonumber(door.z) or 0, not door.loaded and "not loaded" or (door.open and "OPEN" or "closed"))
        end
        lines[#lines + 1] = string.format("Purge: %s | %.2f min remaining <LINE>",
            tostring(airlock.status or "idle"), tonumber(airlock.remainingMinutes) or 0)
        lines[#lines + 1] = "<LINE><H2> Air intakes <LINE>"
        local intakes = {}
        for _, intake in pairs(type(args.intakes) == "table" and args.intakes or {}) do
            intakes[#intakes + 1] = intake
        end
        table.sort(intakes, function(left, right) return tostring(left.id) < tostring(right.id) end)
        for _, intake in ipairs(intakes) do
            lines[#lines + 1] = string.format("%s (%d,%d,Z%d): %s | contamination %.1f%% <LINE>",
                tostring(intake.id), tonumber(intake.x) or 0, tonumber(intake.y) or 0,
                tonumber(intake.z) or 0, tostring(intake.status or "unknown"),
                (tonumber(intake.externalContamination) or 0) * 100)
        end
    end
    if kind ~= "atmosphere" then
        local water = args.water or {}
        lines[#lines + 1] = string.format(
            "<H2> Water <LINE><TEXT> Status: %s | reason: %s <LINE>Requested: %s | powered: %s | physical pump: %s <LINE>",
            tostring(water.status or "offline"), tostring(water.reason or "none"),
            water.pumpRequested and "yes" or "no", water.powerAllocated and "yes" or "no",
            water.pumpActive and "ON" or "OFF")
        lines[#lines + 1] = string.format(
            "Pump condition: %.1f%% | treatment filter: %.1f%% | flow: %.2f L/min <LINE>",
            (tonumber(water.pumpCondition) or 0) * 100,
            (tonumber(water.filterRemaining) or 0) * 100, tonumber(water.flowPerMinute) or 0)
        lines[#lines + 1] = string.format(
            "Storage: %.2f / %.2f L | clean %.2f L | tainted %.2f L <LINE>Source: %s <LINE>",
            tonumber(water.stored) or 0, tonumber(water.capacity) or 0,
            tonumber(water.cleanStored) or 0, tonumber(water.taintedStored) or 0,
            tostring(water.source or "none"))
    end
    local width, height = 780, 560
    local modal = ISModalRichText:new((getCore():getScreenWidth() - width) / 2,
        (getCore():getScreenHeight() - height) / 2, width, height,
        table.concat(lines), false, nil, nil, 0)
    modal:initialise()
    modal.backgroundColor = {r=0, g=0, b=0, a=0.94}
    modal.destroyOnClick = true
    modal.alwaysOnTop = true
    modal:addToUIManager()
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
    elseif command == "qaReport" then
        showQaReport(args)
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

local function addQaMenu(context, player, selected)
    local root = context:addOption("Bunker Campaign: QA tools")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)

    local function submenu(parent, title)
        local option = parent:addOption(title)
        local child = ISContextMenu:getNew(parent)
        parent:addSubMenu(option, child)
        return child
    end

    local travel = submenu(menu, "[QA] Travel and resources")
    local atmosphere = submenu(menu, "[QA] Atmosphere and airlock")
    local water = submenu(menu, "[QA] Water system")

    local function teleport(title, target)
        travel:addOption(title, player, function(p) send(p, "qaTeleport", { target=target }) end)
    end

    teleport("[QA] Exterior toxic zone", "exterior")
    teleport("[QA] Surface air intakes", "intakes")
    teleport("[QA] Dirty entrance", "dirty")
    teleport("[QA] Decontamination chamber", "chamber")
    teleport("[QA] Clean-side exit", "clean")
    teleport("[QA] NBC tablet locker", "reagent")
    travel:addOption("Set body and worn gear to 80%", player, function(p) send(p, "qaContaminate", {}) end)
    travel:addOption("Reset all carried contamination", player, function(p) send(p, "qaClean", {}) end)
    travel:addOption("Give tablets and cleaning agents", player, function(p) send(p, "qaGiveSupplies", {}) end)
    travel:addOption("Refuel main generator", player, function(p)
        send(p, "qaRefuelGenerator", { generator="main" })
    end)
    travel:addOption("Refuel backup generator", player, function(p)
        send(p, "qaRefuelGenerator", { generator="backup" })
    end)
    travel:addOption("Complete decontamination cycle now", player, function(p) send(p, "qaFinishCycle", {}) end)

    atmosphere:addOption("Create 11x11 toxic zone around selected tile (this Z only)", player, function(p)
        send(p, "qaCreateZone", {x=selected.x, y=selected.y, z=selected.z, radius=5})
    end)
    atmosphere:addOption("Create toxic zone over all air intakes (Z=0)", player, function(p)
        send(p, "qaCreateIntakeZone", {})
    end)
    atmosphere:addOption("Remove campaign QA toxic zones", player, function(p) send(p, "qaRemoveZone", {}) end)
    atmosphere:addOption("Break air intake on selected tile", player, function(p)
        send(p, "qaSetIntake", {x=selected.x, y=selected.y, z=selected.z, broken=true})
    end)
    atmosphere:addOption("Repair air intake on selected tile", player, function(p)
        send(p, "qaSetIntake", {x=selected.x, y=selected.y, z=selected.z, broken=false})
    end)
    atmosphere:addOption("Set current room CO2 to 5000 ppm", player, function(p)
        send(p, "qaSetRoomAir", {co2=5000})
    end)
    atmosphere:addOption("Reset current room CO2 to 420 ppm", player, function(p)
        send(p, "qaSetRoomAir", {co2=420})
    end)
    atmosphere:addOption("Set current room airborne contamination to 80%", player, function(p)
        send(p, "qaSetRoomAir", {contamination=0.8})
    end)
    atmosphere:addOption("Clear current room airborne contamination", player, function(p)
        send(p, "qaSetRoomAir", {contamination=0})
    end)
    atmosphere:addOption("Set ventilation filter to 10%", player, function(p)
        send(p, "qaSetVentFilter", {remaining=0.1})
    end)
    atmosphere:addOption("Set ventilation filter to 100%", player, function(p)
        send(p, "qaSetVentFilter", {remaining=1})
    end)
    atmosphere:addOption("Complete active airlock purge now", player, function(p) send(p, "qaFinishPurge", {}) end)
    atmosphere:addOption("Report current room, entry path and purge", player, function(p)
        send(p, "qaReport", {kind="atmosphere"})
    end)

    water:addOption("Fill bunker storage with clean water", player, function(p)
        send(p, "qaWaterStorage", {medium="Water", fillFraction=1})
    end)
    water:addOption("Request bunker water pump ON", player, function(p)
        sendClientCommand(p, "BunkerCampaign", "setConsumer", {id="water", requested=true})
    end)
    water:addOption("Request bunker water pump OFF", player, function(p)
        sendClientCommand(p, "BunkerCampaign", "setConsumer", {id="water", requested=false})
    end)
    water:addOption("STOP pump and EMPTY ALL bunker water storage", player, function(p)
        send(p, "qaWaterStorage", {fillFraction=0, stopPump=true})
    end)
    water:addOption("Fill bunker storage with tainted water", player, function(p)
        send(p, "qaWaterStorage", {medium="TaintedWater", fillFraction=1})
    end)
    water:addOption("Set physical pump condition to 25%", player, function(p)
        send(p, "qaWaterPump", {condition=0.25, burn=false})
    end)
    water:addOption("Repair physical pump to 100%", player, function(p)
        send(p, "qaWaterPump", {condition=1, burn=false})
    end)
    water:addOption("Set Waterpipes treatment filter to 10%", player, function(p)
        send(p, "qaWaterPump", {filterRemaining=0.1})
    end)
    water:addOption("Set Waterpipes treatment filter to 100%", player, function(p)
        send(p, "qaWaterPump", {filterRemaining=1})
    end)
    water:addOption("Add and select 100 L external tainted supply", player, function(p)
        send(p, "qaExternalWater", {})
    end)
    water:addOption("Report physical water state", player, function(p)
        send(p, "qaReport", {kind="water"})
    end)
end

local function selectedTile(playerNum, context, player, worldObjects)
    local pump = Constants.BUNKER_WATER_PUMP
    local objects = type(worldObjects) == "table" and worldObjects or {}
    for _, object in ipairs(objects) do
        if object and object.getX and math.floor(object:getX()) == pump.x
            and math.floor(object:getY()) == pump.y and math.floor(object:getZ()) == pump.z then
            return {x=pump.x, y=pump.y, z=pump.z}
        end
    end

    -- World-object context menus normally contain the floor or another object on
    -- the clicked square.  Use that square before falling back to mouse/player
    -- coordinates so QA zones are centered on the tile the administrator chose.
    for _, object in ipairs(objects) do
        local square = object and object.getSquare and object:getSquare() or nil
        if square and square.getX and square.getY and square.getZ then
            return {x=math.floor(square:getX()), y=math.floor(square:getY()), z=math.floor(square:getZ())}
        end
        if object and object.getX and object.getY and object.getZ then
            return {x=math.floor(object:getX()), y=math.floor(object:getY()), z=math.floor(object:getZ())}
        end
    end

    local z = math.floor(player:getZ())
    local x, y = player:getX(), player:getY()
    if type(getMouseX) == "function" and type(getMouseY) == "function"
        and type(screenToIsoX) == "function" and type(screenToIsoY) == "function" then
        local mouseX, mouseY = getMouseX(), getMouseY()
        x = screenToIsoX(playerNum, mouseX, mouseY, z)
        y = screenToIsoY(playerNum, mouseX, mouseY, z)
    end
    return {x=math.floor(x), y=math.floor(y), z=z}
end

local function addPhysicalPumpControl(context, player, selected)
    local pump = Constants.BUNKER_WATER_PUMP
    if selected.x ~= pump.x or selected.y ~= pump.y or selected.z ~= pump.z then return end
    local state = BunkerCampaign and BunkerCampaign.ClientState and BunkerCampaign.ClientState.snapshot
    local water = state and state.water
    local requested = water and water.requested == true
    context:addOption(requested and "Bunker Campaign: Disable physical water pump"
        or "Bunker Campaign: Enable physical water pump", player, function(p)
        sendClientCommand(p, "BunkerCampaign", "setConsumer", {id="water", requested=not requested})
    end)
end

local function addContextOptions(playerNum, context, worldObjects, test)
    if test and ISWorldObjectContextMenu and ISWorldObjectContextMenu.Test then return true end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    local selected = selectedTile(playerNum, context, player, worldObjects)
    if inside(Rules.INTERACTION, player) then addGameplayMenu(context, player) end
    addPhysicalPumpControl(context, player, selected)
    if isAdministrator() then addQaMenu(context, player, selected) end
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
