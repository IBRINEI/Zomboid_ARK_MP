require "BunkerCampaignIntegration/Constants"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local Constants = BunkerCampaignIntegration.Constants
local Model = {}

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Model.createDefault()
    return {
        status = "idle",
        reagentUnits = 0,
        roomContamination = 0,
        areas = { dirty=0, chamber=0, clean=0 },
        nextCycleId = 1,
        activeCycle = nil,
        lastResult = nil,
    }
end

function Model.normalize(state)
    local defaults = Model.createDefault()
    if type(state) ~= "table" then state = {} end
    if state.status ~= "idle" and state.status ~= "running" and state.status ~= "paused" then state.status = "idle" end
    state.reagentUnits = math.max(0, math.min(Constants.DECONTAMINATION.MAX_REAGENT_UNITS, tonumber(state.reagentUnits) or 0))
    state.roomContamination = math.max(0, math.min(100, tonumber(state.roomContamination) or 0))
    if type(state.areas) ~= "table" then state.areas = {} end
    for _, areaId in ipairs({"dirty", "chamber", "clean"}) do
        state.areas[areaId] = math.max(0, math.min(100, tonumber(state.areas[areaId]) or 0))
    end
    state.nextCycleId = math.max(1, math.floor(tonumber(state.nextCycleId) or 1))
    if type(state.activeCycle) ~= "table" then
        state.activeCycle = nil
        if state.status == "running" or state.status == "paused" then state.status = "idle" end
    else
        local cycle = state.activeCycle
        if not Constants.DECONTAMINATION.MODES[cycle.mode] or type(cycle.username) ~= "string" then
            state.activeCycle = nil
            state.status = "idle"
        else
            cycle.id = math.max(1, math.floor(tonumber(cycle.id) or state.nextCycleId))
            cycle.remainingSeconds = math.max(0, tonumber(cycle.remainingSeconds) or 0)
            cycle.durationSeconds = math.max(0.1, tonumber(cycle.durationSeconds) or 1)
            if not finite(cycle.startedAtWorldAgeHours) then cycle.startedAtWorldAgeHours = 0 end
            local participants = {}
            local seen = {}
            for _, username in ipairs(type(cycle.participants) == "table" and cycle.participants or {cycle.username}) do
                if type(username) == "string" and username ~= "" and not seen[username] then
                    participants[#participants + 1] = username
                    seen[username] = true
                end
            end
            if #participants == 0 then participants[1] = cycle.username end
            cycle.participants = participants
        end
    end
    if state.lastResult ~= nil and type(state.lastResult) ~= "string" then state.lastResult = tostring(state.lastResult) end
    return state
end

function Model.precheck(modeId, resources)
    local mode = Constants.DECONTAMINATION.MODES[modeId]
    if not mode then return false, "unknown_mode" end
    resources = type(resources) == "table" and resources or {}
    if (tonumber(resources.cleanWaterLiters) or 0) + 0.0001 < mode.waterLiters then return false, "clean_water_required" end
    if mode.requiresPower and resources.powerAllocated ~= true then return false, "power_required" end
    if mode.inventoryReagent and resources.inventoryReagent ~= true then return false, "cleaning_agent_required" end
    if mode.mixerUnits and (tonumber(resources.mixerUnits) or 0) < mode.mixerUnits then return false, "nbc_solution_required" end
    return true
end

function Model.start(state, modeId, username, worldAgeHours)
    state = Model.normalize(state)
    local mode = Constants.DECONTAMINATION.MODES[modeId]
    if not mode then return nil, "unknown_mode" end
    if state.activeCycle then return nil, "cycle_active" end
    local cycle = {
        id = state.nextCycleId,
        mode = modeId,
        username = username,
        durationSeconds = mode.durationSeconds,
        remainingSeconds = mode.durationSeconds,
        startedAtWorldAgeHours = tonumber(worldAgeHours) or 0,
        participants = { username },
    }
    state.nextCycleId = state.nextCycleId + 1
    state.activeCycle = cycle
    state.status = "running"
    state.lastResult = nil
    return cycle
end

function Model.advance(state, elapsedSeconds, canRun)
    state = Model.normalize(state)
    local cycle = state.activeCycle
    if not cycle then return false, "idle" end
    if canRun == false then state.status = "paused"; return false, "paused" end
    state.status = "running"
    cycle.remainingSeconds = math.max(0, cycle.remainingSeconds - math.max(0, tonumber(elapsedSeconds) or 0))
    return cycle.remainingSeconds <= 0, cycle.remainingSeconds <= 0 and "complete" or "running"
end

function Model.finish(state, result)
    state = Model.normalize(state)
    state.activeCycle = nil
    state.status = "idle"
    state.lastResult = tostring(result or "complete")
end

BunkerCampaignIntegration.DecontaminationModel = Model
return Model
