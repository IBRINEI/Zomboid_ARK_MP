if isClient() then return end

require "BunkerCampaign/Constants"
require "BunkerCampaign/CampaignState"
require "BunkerCampaign/HeatingComponents"
require "BunkerCampaign/HeatingSimulation"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local CampaignState = BunkerCampaign.CampaignState
local HeatingComponents = BunkerCampaign.HeatingComponents
local HeatingSimulation = BunkerCampaign.HeatingSimulation
local ServerCommands = {
    lastStateRequest = {},
    debug = {},
}

local function isAdministrator(player)
    return player ~= nil and player:isAccessLevel("admin")
end

local function canOperateBunkerSystems(player)
    if not player or type(player.getX) ~= "function" or type(player.getY) ~= "function" or type(player.getZ) ~= "function" then return false end
    local bounds = Constants.BUNKER_CONTROL_BOUNDS
    local x, y, z = player:getX(), player:getY(), math.floor(player:getZ())
    return x >= bounds.x1 and x <= bounds.x2
        and y >= bounds.y1 and y <= bounds.y2
        and bounds.levels[z] == true
end

local function heatingState()
    local state = CampaignState.get()
    return state and state.bunker and state.bunker.modules
        and state.bunker.modules.heating or nil
end

local function isNearHeatingComponent(player, componentId)
    return HeatingComponents.isNear(player, HeatingComponents.get(componentId),
        Constants.HEATING.COMPONENT_INTERACTION_DISTANCE)
end

local function physicalHeatingObjectExists(componentId)
    local definition = HeatingComponents.get(componentId)
    if not definition or type(getCell) ~= "function" then return false end
    local square = getCell():getGridSquare(definition.x, definition.y, definition.z)
    local objects = square and square:getObjects() or nil
    if not objects then return false end
    for index = 0, objects:size() - 1 do
        local object = objects:get(index)
        local sprite = object and object:getSprite() or nil
        if sprite and sprite:getName() == definition.sprite then return true end
    end
    return false
end

local function canUseHeatingController(player)
    if not isNearHeatingComponent(player, "controller") then
        return false, "heating_controller_required"
    end
    local heating = heatingState()
    if not heating or not HeatingSimulation.controllerOperational(heating) then
        return false, "heating_controller_offline"
    end
    return true
end

local function perkForName(name)
    if not Perks then return nil end
    if name == "Electricity" then return Perks.Electricity end
    if name == "Mechanics" then return Perks.Mechanics end
    if name == "MetalWelding" then return Perks.MetalWelding end
    return nil
end

local function requiredSkillLevel(required, mode)
    if mode == "diagnose" then return math.max(1, math.floor(required / 2)) end
    if mode == "temporary" then return math.max(0, required - 1) end
    return required
end

local function validateSkills(player, definition, mode)
    local surplus, count = 0, 0
    for name, required in pairs(definition.skills or {}) do
        local perk = perkForName(name)
        local current = perk and player:getPerkLevel(perk) or 0
        local needed = requiredSkillLevel(required, mode)
        if current < needed then return false, "heating_skill_required" end
        surplus = surplus + math.max(0, current - required)
        count = count + 1
    end
    return true, count > 0 and surplus / count or 0
end

local function inventoryItem(inventory, fullType)
    return inventory and inventory:getFirstTypeRecurse(fullType) or nil
end

local function validateRepairInventory(player, definition, mode)
    local inventory = player and player:getInventory()
    if not inventory then return false, "inventory_unavailable" end
    if mode == "full" then
        for _, fullType in ipairs(definition.tools or {}) do
            if not inventoryItem(inventory, fullType) then
                return false, "heating_tool_required"
            end
        end
    end
    local materials = mode == "temporary"
        and definition.temporaryMaterials or definition.materials
    for fullType, count in pairs(materials or {}) do
        if inventory:getNumberOfItem(fullType, false, true) < count then
            return false, "heating_material_required"
        end
    end
    return true, materials
end

local function consumeRepairMaterials(player, materials)
    local inventory = player:getInventory()
    for fullType, count in pairs(materials or {}) do
        for _ = 1, count do
            local item = inventoryItem(inventory, fullType)
            if not item or not item:getContainer() then return false end
            local container = item:getContainer()
            container:Remove(item)
            if type(sendRemoveItemFromContainer) == "function" then
                sendRemoveItemFromContainer(container, item)
            end
        end
    end
    return true
end

local function grantRepairXp(player, definition, amount)
    local xp = player and player:getXp()
    if not xp then return end
    for name in pairs(definition.skills or {}) do
        local perk = perkForName(name)
        if perk then pcall(xp.AddXP, xp, perk, amount) end
    end
end

local function replyError(player, code)
    ServerCommands.debug.lastValidation = {success=false, reason=code}
    ServerCommands.debug.lastError = tostring(code or "unknown_error")
    if isServer() and player then
        sendServerCommand(player, Constants.NETWORK_MODULE, "commandError", { code = code })
    end
end

local function requestState(player, args)
    if not player then return end
    local username = player:getUsername()
    local now = getGametimeTimestamp()
    local previous = ServerCommands.lastStateRequest[username] or 0
    if now - previous < 500 then return end
    ServerCommands.lastStateRequest[username] = now
    CampaignState.sendToPlayer(player, {
        correlationId=type(args) == "table" and args.correlationId or nil,
    })
end

local function setVentilation(player, args)
    if not canOperateBunkerSystems(player) then
        CampaignState.appendLog("security", "rejected ventilation mutation", player and player:getUsername() or "unknown")
        replyError(player, "bunker_access_required")
        return
    end
    if type(args) ~= "table" or type(args.enabled) ~= "boolean" then
        CampaignState.appendLog("security", "rejected malformed ventilation command", player:getUsername())
        replyError(player, "invalid_payload")
        return
    end

    local ok, reason = CampaignState.setVentilationEnabled(args.enabled, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setVentilationMode(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    if type(args) ~= "table" or type(args.mode) ~= "string" then replyError(player, "invalid_payload"); return end
    local ok, reason = CampaignState.setVentilationMode(args.mode, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function startAirlockPurge(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    local roomId = type(args) == "table" and args.roomId or "decontamination_chamber"
    if type(roomId) ~= "string" then replyError(player, "invalid_payload"); return end
    local ok, reason = CampaignState.startAirlockPurge(roomId, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function filterCharge(item)
    if item and type(item.getUsedDelta) == "function" then
        local ok, remaining = pcall(item.getUsedDelta, item)
        if ok and tonumber(remaining) then return math.max(0, math.min(1, tonumber(remaining))) end
    end
    local md = item and item:getModData() or nil
    local charge = md and tonumber(md.BunkerCampaignVentFilterRemaining or md.percent) or nil
    if charge then return math.max(0, math.min(1, charge)) end
    return 1
end

local function applyVentilationFilterCharge(item, charge)
    if not item then return end
    charge = math.max(0, math.min(1, tonumber(charge) or 0))
    if type(item.setUsedDelta) == "function" then item:setUsedDelta(charge) end
    local md = item:getModData()
    md.BunkerCampaignVentFilterRemaining = nil
    md.percent = nil
    if type(item.syncItemFields) == "function" then item:syncItemFields() end
end

local function replaceVentilationFilter(player)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    local inventory = player and player:getInventory()
    local item = inventory and inventory:getFirstTypeRecurse("Base.GasmaskFilter") or nil
    if not item then replyError(player, "ventilation_filter_required"); return end
    local charge = filterCharge(item)
    local container = item:getContainer()
    if not container then replyError(player, "filter_transaction_failed"); return end
    container:Remove(item)
    if type(sendRemoveItemFromContainer) == "function" then sendRemoveItemFromContainer(container, item) end
    local ok, previous = CampaignState.replaceVentilationFilter(charge, player:getUsername())
    if not ok then replyError(player, previous or "filter_transaction_failed"); return end
    if previous > 0.001 then
        local used = inventory:AddItem("Base.GasmaskFilter")
        if used then
            applyVentilationFilterCharge(used, previous)
            if type(sendAddItemToContainer) == "function" then sendAddItemToContainer(inventory, used) end
        end
    end
end

local function setWaterSource(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    if type(args) ~= "table" or type(args.id) ~= "string" then replyError(player, "invalid_payload"); return end
    local ok, reason = CampaignState.setWaterSource(args.id, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setWaterBypass(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    if type(args) ~= "table" or type(args.enabled) ~= "boolean" then replyError(player, "invalid_payload"); return end
    local ok, reason = CampaignState.setWaterBypass(args.enabled, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setHeating(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    local allowed, controlReason = canUseHeatingController(player)
    if not allowed then replyError(player, controlReason); return end
    if type(args) ~= "table" or type(args.enabled) ~= "boolean" then
        replyError(player, "invalid_payload"); return
    end
    local ok, reason = CampaignState.setHeatingEnabled(args.enabled, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setHeatingTarget(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    local allowed, controlReason = canUseHeatingController(player)
    if not allowed then replyError(player, controlReason); return end
    if type(args) ~= "table" or type(args.temperature) ~= "number" then
        replyError(player, "invalid_payload"); return
    end
    local ok, reason = CampaignState.setHeatingTarget(args.temperature, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setHeatingRoom(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    local allowed, controlReason = canUseHeatingController(player)
    if not allowed then replyError(player, controlReason); return end
    if type(args) ~= "table" or type(args.roomId) ~= "string"
        or type(args.enabled) ~= "boolean" then
        replyError(player, "invalid_payload"); return
    end
    local ok, reason = CampaignState.setHeatingRoomEnabled(
        args.roomId, args.enabled, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function diagnoseHeatingComponent(player, args)
    local componentId = type(args) == "table" and args.componentId or nil
    local definition = HeatingComponents.get(componentId)
    if not definition then replyError(player, "unknown_heating_component"); return end
    if not isNearHeatingComponent(player, componentId) then
        replyError(player, "heating_component_distance"); return
    end
    if not physicalHeatingObjectExists(componentId) then
        replyError(player, "heating_component_missing"); return
    end
    local skilled, reason = validateSkills(player, definition, "diagnose")
    if not skilled then replyError(player, reason); return end
    local ok, result = CampaignState.diagnoseHeatingComponent(
        componentId, player:getUsername())
    if not ok then replyError(player, result or "heating_diagnosis_failed"); return end
    grantRepairXp(player, definition, 1)
end

local function repairHeatingComponent(player, args)
    local componentId = type(args) == "table" and args.componentId or nil
    local mode = type(args) == "table" and args.mode or nil
    local definition = HeatingComponents.get(componentId)
    if not definition or (mode ~= "temporary" and mode ~= "full") then
        replyError(player, "invalid_payload"); return
    end
    if not isNearHeatingComponent(player, componentId) then
        replyError(player, "heating_component_distance"); return
    end
    if not physicalHeatingObjectExists(componentId) then
        replyError(player, "heating_component_missing"); return
    end
    local skilled, surplusOrReason = validateSkills(player, definition, mode)
    if not skilled then replyError(player, surplusOrReason); return end
    local inventoryOk, materialsOrReason = validateRepairInventory(player, definition, mode)
    if not inventoryOk then replyError(player, materialsOrReason); return end
    local heating = heatingState()
    local component = heating and heating.components and heating.components[componentId]
    if not component or (component.fault == "none"
        and component.condition >= (mode == "full" and 0.90 or 0.40)
        and (component.integrity == nil or component.integrity >= 0.90)) then
        replyError(player, "repair_not_needed"); return
    end
    if not consumeRepairMaterials(player, materialsOrReason) then
        replyError(player, "heating_material_transaction_failed"); return
    end
    local improvement = 0.25 + math.min(0.15, (tonumber(surplusOrReason) or 0) * 0.03)
    local ok, reason = CampaignState.repairHeatingComponent(
        componentId, mode, improvement, player:getUsername())
    if not ok then replyError(player, reason or "heating_repair_failed"); return end
    grantRepairXp(player, definition, mode == "full" and 5 or 2)
end

local function setHeatingValve(player, args)
    local componentId = type(args) == "table" and args.componentId or nil
    if type(args) ~= "table" or type(args.open) ~= "boolean"
        or not HeatingComponents.get(componentId) then
        replyError(player, "invalid_payload"); return
    end
    if not isNearHeatingComponent(player, componentId) then
        replyError(player, "heating_component_distance"); return
    end
    if not physicalHeatingObjectExists(componentId) then
        replyError(player, "heating_component_missing"); return
    end
    local ok, reason = CampaignState.setHeatingValve(
        componentId, args.open, player:getUsername())
    if not ok then replyError(player, reason or "heating_valve_failed") end
end

local function setHeatingManualBypass(player, args)
    if type(args) ~= "table" or type(args.enabled) ~= "boolean" then
        replyError(player, "invalid_payload"); return
    end
    if not isNearHeatingComponent(player, "heat_exchanger") then
        replyError(player, "heating_component_distance"); return
    end
    if not physicalHeatingObjectExists("heat_exchanger") then
        replyError(player, "heating_component_missing"); return
    end
    local ok, reason = CampaignState.setHeatingManualBypass(
        args.enabled, player:getUsername())
    if not ok then replyError(player, reason or "heating_bypass_failed") end
end

local function triggerHeatingFault(player, args)
    if not isAdministrator(player) then replyError(player, "admin_required"); return end
    if type(args) ~= "table" or type(args.componentId) ~= "string"
        or type(args.severity) ~= "string" then
        replyError(player, "invalid_payload"); return
    end
    local ok, reason = CampaignState.triggerHeatingFault(
        args.componentId, args.severity, player:getUsername())
    if not ok then replyError(player, reason or "heating_failure_failed") end
end

local function qaHeating(player, args)
    if not isAdministrator(player) then replyError(player, "admin_required"); return end
    if type(args) ~= "table" or type(args.action) ~= "string" then
        replyError(player, "invalid_payload"); return
    end
    local ok, reason = CampaignState.applyHeatingQa(
        args.action, args, player:getUsername())
    if not ok then replyError(player, reason or "heating_qa_failed") end
end

local function qaHeatingRepairKit(player)
    if not isAdministrator(player) then replyError(player, "admin_required"); return end
    local inventory = player and player:getInventory()
    if not inventory then replyError(player, "inventory_unavailable"); return end
    local counts = {}
    for _, componentId in ipairs(HeatingComponents.orderedIds()) do
        local definition = HeatingComponents.get(componentId)
        for _, fullType in ipairs(definition.tools or {}) do
            counts[fullType] = math.max(1, counts[fullType] or 0)
        end
        for fullType, count in pairs(definition.materials or {}) do
            counts[fullType] = (counts[fullType] or 0) + count
        end
        for fullType, count in pairs(definition.temporaryMaterials or {}) do
            counts[fullType] = (counts[fullType] or 0) + count
        end
    end
    for fullType, count in pairs(counts) do
        for _ = 1, count do
            local item = inventory:AddItem(fullType)
            if not item then replyError(player, "heating_qa_item_unavailable"); return end
            if type(sendAddItemToContainer) == "function" then
                sendAddItemToContainer(inventory, item)
            end
        end
    end
    CampaignState.appendLog("qa", "complete heating repair kit issued",
        player:getUsername())
end

local function setGenerator(player, args)
    if not canOperateBunkerSystems(player) then
        CampaignState.appendLog("security", "rejected generator mutation", player and player:getUsername() or "unknown")
        replyError(player, "bunker_access_required")
        return
    end
    if type(args) ~= "table" or type(args.id) ~= "string" or type(args.requested) ~= "boolean" then
        replyError(player, "invalid_payload")
        return
    end
    local ok, reason = CampaignState.setGeneratorRequested(args.id, args.requested, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setConsumer(player, args)
    if not canOperateBunkerSystems(player) then
        CampaignState.appendLog("security", "rejected consumer mutation", player and player:getUsername() or "unknown")
        replyError(player, "bunker_access_required")
        return
    end
    if type(args) ~= "table" or type(args.id) ~= "string" or type(args.requested) ~= "boolean" then
        replyError(player, "invalid_payload")
        return
    end
    local allowed = { ventilation=true, water=true, heating=true, main_lighting=true }
    if not allowed[args.id] then replyError(player, "unknown_consumer"); return end
    local ok, reason = CampaignState.setConsumerRequested(args.id, args.requested, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

function ServerCommands.onClientCommand(module, command, player, args)
    if module ~= Constants.NETWORK_MODULE then return end
    ServerCommands.debug.lastReceivedCommand = {
        module=module,
        command=command,
        username=player and player:getUsername() or "unknown",
        correlationId=type(args) == "table" and args.correlationId or nil,
    }
    ServerCommands.debug.lastValidation = {success=true, reason=nil}
    ServerCommands.debug.lastError = nil

    if command == "requestState" then
        requestState(player, args)
    elseif command == "setVentilation" then
        setVentilation(player, args)
    elseif command == "setVentilationMode" then
        setVentilationMode(player, args)
    elseif command == "startAirlockPurge" then
        startAirlockPurge(player, args)
    elseif command == "replaceVentilationFilter" then
        replaceVentilationFilter(player)
    elseif command == "setWaterSource" then
        setWaterSource(player, args)
    elseif command == "setWaterBypass" then
        setWaterBypass(player, args)
    elseif command == "setHeating" then
        setHeating(player, args)
    elseif command == "setHeatingTarget" then
        setHeatingTarget(player, args)
    elseif command == "setHeatingRoom" then
        setHeatingRoom(player, args)
    elseif command == "diagnoseHeatingComponent" then
        diagnoseHeatingComponent(player, args)
    elseif command == "repairHeatingComponent" then
        repairHeatingComponent(player, args)
    elseif command == "setHeatingValve" then
        setHeatingValve(player, args)
    elseif command == "setHeatingManualBypass" then
        setHeatingManualBypass(player, args)
    elseif command == "triggerHeatingFault" then
        triggerHeatingFault(player, args)
    elseif command == "qaHeating" then
        qaHeating(player, args)
    elseif command == "qaHeatingRepairKit" then
        qaHeatingRepairKit(player)
    elseif command == "setGenerator" then
        setGenerator(player, args)
    elseif command == "setConsumer" then
        setConsumer(player, args)
    else
        CampaignState.appendLog("security", "rejected unknown command " .. tostring(command), player and player:getUsername() or "unknown")
        replyError(player, "unknown_command")
    end
    if ServerCommands.debug.lastValidation.success then
        ServerCommands.debug.lastMutation = {
            command=command,
            username=player and player:getUsername() or "unknown",
        }
    end
end

BunkerCampaign.Runtime = BunkerCampaign.Runtime or {}
if BunkerCampaign.Runtime.onClientCommand
    and type(Events.OnClientCommand.Remove) == "function" then
    Events.OnClientCommand.Remove(BunkerCampaign.Runtime.onClientCommand)
end
BunkerCampaign.Runtime.onClientCommand = ServerCommands.onClientCommand
Events.OnClientCommand.Add(BunkerCampaign.Runtime.onClientCommand)

BunkerCampaign.Debug = BunkerCampaign.Debug or {}
function BunkerCampaign.Debug.getServerState()
    local state = CampaignState.get()
    local modules = state and state.bunker and state.bunker.modules or {}
    return {
        context="server",
        revision=state and state.revision or nil,
        powerStatus=modules.power and modules.power.status or nil,
        ventilationStatus=modules.ventilation and modules.ventilation.status or nil,
        waterStatus=modules.water and modules.water.status or nil,
        heatingStatus=modules.heating and modules.heating.status or nil,
        lastReceivedCommand=ServerCommands.debug.lastReceivedCommand,
        lastValidation=ServerCommands.debug.lastValidation,
        lastMutation=ServerCommands.debug.lastMutation,
        lastError=ServerCommands.debug.lastError,
    }
end
function BunkerCampaign.Debug.getLastServerCommand()
    return ServerCommands.debug.lastReceivedCommand
end
function BunkerCampaign.Debug.getLastServerError() return ServerCommands.debug.lastError end
function BunkerCampaign.Debug.runServerScenario(name)
    if name == "snapshot" then return BunkerCampaign.Debug.getServerState() end
    return {ok=false, code="unknown_scenario"}
end
function BunkerCampaign.Debug.resetServerState()
    ServerCommands.debug = {}
    return true
end

BunkerCampaign.ServerCommands = ServerCommands
return ServerCommands
