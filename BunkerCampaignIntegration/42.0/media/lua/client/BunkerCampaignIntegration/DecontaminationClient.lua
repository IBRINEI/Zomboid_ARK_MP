require "ISUI/ISContextMenu"
require "ISUI/ISModalRichText"
require "ISUI/ISToolTip"
require "TimedActions/ISTimedActionQueue"
require "BunkerCampaignIntegration/Constants"
require "BunkerCampaignIntegration/ManualWashClient"
require "BunkerCampaignIntegration/DecontaminationEffects"
require "BunkerCampaignIntegration/RepairIntakeAction"

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
            "Vent filter: %.2f%% | use %.4f%%/min | activity %s | recirc cleaning %.2f contaminated m3/min <LINE>",
            (tonumber(args.filterRemaining) or 0) * 100,
            (tonumber(args.filterUsePerMinute) or 0) * 100,
            tostring(args.filterActivity or "unknown"),
            tonumber(args.recirculationRemovedM3PerMinute) or 0)
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
            lines[#lines + 1] = string.format("%s (%d,%d,Z%d): %s | condition %.0f%% | contamination %.1f%% <LINE>",
                tostring(intake.id), tonumber(intake.x) or 0, tonumber(intake.y) or 0,
                tonumber(intake.z) or 0, tostring(intake.status or "unknown"),
                (tonumber(intake.condition) or 0) * 100,
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
            "Pump condition: %.1f%% | treatment filter: %.1f%% | use: %.2f%%/min | flow: %.2f L/min <LINE>",
            (tonumber(water.pumpCondition) or 0) * 100,
            (tonumber(water.filterRemaining) or 0) * 100,
            (tonumber(water.filterUsePerMinute) or 0) * 100,
            tonumber(water.flowPerMinute) or 0)
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
        "%s (%.0f L water%s; body -%.0f%%, gear -%.0f%%)",
        title,
        mode.waterLiters,
        mode.requiresPower and ", power" or "",
        (tonumber(mode.bodyRemoval) or 0) * 100,
        (tonumber(mode.gearRemoval) or 0) * 100
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
    local heating = submenu(menu, "[QA] Heating system")

    local function teleport(title, target)
        travel:addOption(title, player, function(p) send(p, "qaTeleport", { target=target }) end)
    end

    teleport("[QA] Exterior toxic zone", "exterior")
    teleport("[QA] Surface air intakes", "intakes")
    teleport("[QA] Dirty entrance", "dirty")
    teleport("[QA] Decontamination chamber", "chamber")
    teleport("[QA] Clean-side exit", "clean")
    teleport("[QA] NBC tablet locker", "reagent")
    teleport("[QA] Bunker arrival point", "spawn")
    teleport("[QA] Heating controller", "heating_controller")
    teleport("[QA] Heat exchanger", "heat_exchanger")
    teleport("[QA] Circulation blower", "circulation_blower")
    teleport("[QA] Heating supply valve", "supply_valve")
    teleport("[QA] Heating return valve", "return_valve")
    teleport("[QA] Heating pipe manifold", "pipe_manifold")
    travel:addOption("[QA] Inspect service level", player, function(p)
        sendClientCommand(p, "BunkerCampaignArkMP", "inspectLevel", {level="service"})
    end)
    travel:addOption("[QA] Inspect deep level", player, function(p)
        sendClientCommand(p, "BunkerCampaignArkMP", "inspectLevel", {level="deep"})
    end)
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
    water:addOption("STOP pump and fill storage with tainted water", player, function(p)
        send(p, "qaWaterStorage", {medium="TaintedWater", fillFraction=1, stopPump=true})
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
    water:addOption("REMOVE Waterpipes treatment filter (0%)", player, function(p)
        send(p, "qaWaterPump", {filterRemaining=0})
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

    local function heatingQa(title, action, args)
        heating:addOption(title, player, function(p)
            local payload = {}
            for key, value in pairs(args or {}) do payload[key] = value end
            payload.action = action
            sendClientCommand(p, "BunkerCampaign", "qaHeating", payload)
        end)
    end

    heating:addOption("[QA] Give complete heating repair kit", player, function(p)
        sendClientCommand(p, "BunkerCampaign", "qaHeatingRepairKit", {})
    end)
    heating:addOption("[QA] Set heating repair skills to 10", player, function(p)
        p:setPerkLevelDebug(Perks.Electricity, 10)
        p:setPerkLevelDebug(Perks.Mechanics, 10)
        p:setPerkLevelDebug(Perks.MetalWelding, 10)
        if type(SyncXp) == "function" then SyncXp(p) end
    end)
    heatingQa("[QA] Prepare cold powered test (+5 C rooms)", "ready")
    heatingQa("[QA] Restore all heating components to 90%", "restore_all")
    heatingQa("[QA] Set every room to +21 C", "rooms", {temperature=21})
    heatingQa("[QA] Set every room to +5 C", "rooms", {temperature=5})
    heatingQa("[QA] Set every room to -20 C", "rooms", {temperature=-20})
    heatingQa("[QA] Stop both generators (force power shed)", "power_shed")
    heatingQa("[QA] Ventilation OFF with heating requested", "ventilation_off")
    heatingQa("[QA] Internal recirculation ON with heating requested", "circulation_on")
    heatingQa("[QA] Enable manual circulation bypass", "manual_bypass", {enabled=true})
    heatingQa("[QA] Disable manual circulation bypass", "manual_bypass", {enabled=false})
    heatingQa("[QA] Open both heating valves", "valves", {supplyOpen=true,returnOpen=true})
    heatingQa("[QA] Close supply valve", "valves", {supplyOpen=false,returnOpen=true})
    heatingQa("[QA] Close return valve", "valves", {supplyOpen=true,returnOpen=false})

    local componentLabels = {
        controller="Controller",
        heat_exchanger="Heat exchanger",
        circulation_blower="Circulation blower",
        supply_valve="Supply valve",
        return_valve="Return valve",
        pipe_manifold="Pipe manifold",
    }
    local componentOrder = {
        "controller", "heat_exchanger", "circulation_blower",
        "supply_valve", "return_valve", "pipe_manifold",
    }
    for _, componentId in ipairs(componentOrder) do
        local id = componentId
        local componentMenu = submenu(heating, "[QA] " .. componentLabels[id])
        local function componentState(title, state)
            componentMenu:addOption(title, player, function(p)
                sendClientCommand(p, "BunkerCampaign", "qaHeating", {
                    action="component", componentId=id, state=state,
                })
            end)
        end
        componentState("Restore to 90%", "healthy")
        componentState("Set diagnosed minor fault", "minor")
        componentState("Set diagnosed major fault", "major")
        componentMenu:addOption("Teleport to component", player, function(p)
            send(p, "qaTeleport", {target=id == "controller"
                and "heating_controller" or id})
        end)
    end
end

local function selectedTile(playerNum, context, player, worldObjects)
    local pump = Constants.BUNKER_WATER_PUMP
    local objects = type(worldObjects) == "table" and worldObjects or {}
    for _, object in ipairs(objects) do
        if object and object.getX and math.floor(object:getX()) == pump.x
            and math.floor(object:getY()) == pump.y and math.floor(object:getZ()) == pump.z then
            return {x=pump.x, y=pump.y, z=pump.z, square=object:getSquare()}
        end
    end

    -- World-object context menus normally contain the floor or another object on
    -- the clicked square.  Use that square before falling back to mouse/player
    -- coordinates so QA zones are centered on the tile the administrator chose.
    for _, object in ipairs(objects) do
        local square = object and object.getSquare and object:getSquare() or nil
        if square and square.getX and square.getY and square.getZ then
            return {x=math.floor(square:getX()), y=math.floor(square:getY()), z=math.floor(square:getZ()), square=square}
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
    local tileX, tileY = math.floor(x), math.floor(y)
    local square = getCell() and getCell():getGridSquare(tileX, tileY, z) or nil
    return {x=tileX, y=tileY, z=z, square=square}
end

local function intakeAt(selected)
    local state = BunkerCampaign and BunkerCampaign.ClientState and BunkerCampaign.ClientState.snapshot
    local ventilation = state and state.ventilation
    for _, intake in pairs(ventilation and ventilation.intakes or {}) do
        if math.floor(tonumber(intake.x) or 0) == selected.x
            and math.floor(tonumber(intake.y) or 0) == selected.y
            and math.floor(tonumber(intake.z) or 0) == selected.z then
            return intake
        end
    end
    return nil
end

local function queueIntakeRepair(player, selected, scrap)
    if not player or not selected.square or not scrap then return end
    if luautils.walkAdj(player, selected.square) then
        ISTimedActionQueue.add(BunkerCampaignIntegration.RepairIntakeAction:new(
            player, scrap, selected.x, selected.y, selected.z))
    end
end

local function addIntakeRepair(context, player, selected)
    local intake = intakeAt(selected)
    if not intake then return end
    local info = context:addOption(string.format("Bunker air intake %s: %s | condition %.0f%%",
        tostring(intake.id or "unknown"), tostring(intake.status or "unknown"),
        (tonumber(intake.condition) or 0) * 100))
    info.notAvailable = true
    if intake.broken ~= true then return end
    local scrap = player:getInventory():getFirstTypeRecurse("Base.ScrapMetal")
    local option = context:addOption("Repair bunker air intake (1 Scrap Metal)", player,
        queueIntakeRepair, selected, scrap)
    option.notAvailable = scrap == nil or selected.square == nil
    if option.notAvailable then
        option.toolTip = ISToolTip:new()
        option.toolTip:initialise()
        option.toolTip.description = scrap == nil and "Requires 1 Scrap Metal"
            or "The intake tile is not loaded"
    end
end

local function addVentilationModuleStatus(context, selected)
    local bounds = Constants.VENTILATION_MODULE_BOUNDS
    if selected.z ~= bounds.z or selected.x < bounds.x1 or selected.x > bounds.x2
        or selected.y < bounds.y1 or selected.y > bounds.y2 then return end
    local state = BunkerCampaign and BunkerCampaign.ClientState and BunkerCampaign.ClientState.snapshot
    local ventilation = state and state.ventilation
    if not ventilation then return end
    local telemetry = ventilation.telemetry or {}
    local intakeTotal = 0
    for _ in pairs(ventilation.intakes or {}) do intakeTotal = intakeTotal + 1 end
    local root = context:addOption("Bunker ventilation: " .. tostring(ventilation.status or "unknown")
        .. " | " .. tostring(ventilation.activeMode or "off"))
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    local function statusLine(text)
        local option = menu:addOption(text)
        option.notAvailable = true
    end
    local modeEffect = {
        off="fan off; passive outside leakage",
        sealed="fan off; outside exchange isolated",
        internal_recirculation="powered internal mixing and cleaning; no fresh air",
        external_filtration="filtered fresh-air exchange",
        emergency_ventilation="maximum filtered fresh-air exchange",
    }
    statusLine("Requested: " .. tostring(ventilation.requestedMode or "off")
        .. " | restriction: " .. tostring(ventilation.reason or "none"))
    statusLine("Effect: " .. tostring(modeEffect[ventilation.activeMode] or "unknown"))
    statusLine(string.format("Unit %.0f%% | fan %.0f%% | intakes %d/%d",
        (tonumber(ventilation.condition) or 0) * 100,
        (tonumber(ventilation.fanCondition) or 0) * 100,
        tonumber(telemetry.activeIntakes) or 0, intakeTotal))
    statusLine(string.format("Airflow %.0f m3/min | outside exchange %.2f m3/min",
        tonumber(ventilation.airflowM3PerMinute) or 0,
        tonumber(telemetry.outsideExchangeM3PerMinute) or 0))
    statusLine(string.format("Filter %.2f%% | use %.4f%%/min | %s",
        (tonumber(ventilation.filterRemaining) or 0) * 100,
        (tonumber(telemetry.filterUsePerMinute) or 0) * 100,
        tostring(telemetry.filterActivity or "unknown")))
    statusLine(string.format("CO2 %.0f ppm | internal air %.2f%%",
        tonumber(ventilation.co2) or 0,
        (tonumber(ventilation.internalContamination) or 0) * 100))
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
    addVentilationModuleStatus(context, selected)
    addIntakeRepair(context, player, selected)
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

BunkerCampaignIntegration.Runtime = BunkerCampaignIntegration.Runtime or {}
local runtime = BunkerCampaignIntegration.Runtime.decontaminationClient or {}
if runtime.onCreatePlayer and type(Events.OnCreatePlayer.Remove) == "function" then
    Events.OnCreatePlayer.Remove(runtime.onCreatePlayer)
end
if runtime.onServerCommand and type(Events.OnServerCommand.Remove) == "function" then
    Events.OnServerCommand.Remove(runtime.onServerCommand)
end
if runtime.addContextOptions
    and type(Events.OnFillWorldObjectContextMenu.Remove) == "function" then
    Events.OnFillWorldObjectContextMenu.Remove(runtime.addContextOptions)
end
if runtime.draw and type(Events.OnPreUIDraw.Remove) == "function" then
    Events.OnPreUIDraw.Remove(runtime.draw)
end
runtime.onCreatePlayer = onCreatePlayer
runtime.onServerCommand = onServerCommand
runtime.addContextOptions = addContextOptions
runtime.draw = draw
BunkerCampaignIntegration.Runtime.decontaminationClient = runtime
Events.OnCreatePlayer.Add(runtime.onCreatePlayer)
Events.OnServerCommand.Add(runtime.onServerCommand)
Events.OnFillWorldObjectContextMenu.Add(runtime.addContextOptions)
Events.OnPreUIDraw.Add(runtime.draw)

BunkerCampaignIntegration.DecontaminationClient = Client
return Client
