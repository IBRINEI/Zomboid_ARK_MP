BunkerCampaign = BunkerCampaign or {}

local RoomRegistry = {
    definitions = {},
    order = {},
}

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function number(value, fallback, minimum)
    value = tonumber(value)
    if not finite(value) then value = fallback end
    if minimum and value < minimum then value = minimum end
    return value
end

local function copyPoint(point)
    return {
        x = number(point and point.x, 0),
        y = number(point and point.y, 0),
        z = math.floor(number(point and point.z, 0)),
    }
end

local function normalizeDefinition(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string" or definition.id == "" then
        return nil, "room_id_required"
    end
    local bounds = definition.bounds
    if type(bounds) ~= "table" then return nil, "room_bounds_required" end
    local normalized = {
        id = definition.id,
        label = type(definition.label) == "string" and definition.label or definition.id,
        kind = type(definition.kind) == "string" and definition.kind or "habitable",
        bounds = {
            x1 = number(bounds.x1, 0), x2 = number(bounds.x2, 0),
            y1 = number(bounds.y1, 0), y2 = number(bounds.y2, 0),
            z = math.floor(number(bounds.z, 0)),
        },
        heightMeters = number(definition.heightMeters, 2.8, 0.5),
        volumeM3 = number(definition.volumeM3, 0, 0),
        ventWeight = number(definition.ventWeight, 1, 0),
        leakRate = number(definition.leakRate, 0.002, 0),
        vents = {},
        connections = {},
    }
    if normalized.bounds.x2 < normalized.bounds.x1 then
        normalized.bounds.x1, normalized.bounds.x2 = normalized.bounds.x2, normalized.bounds.x1
    end
    if normalized.bounds.y2 < normalized.bounds.y1 then
        normalized.bounds.y1, normalized.bounds.y2 = normalized.bounds.y2, normalized.bounds.y1
    end
    if normalized.volumeM3 <= 0 then
        normalized.volumeM3 = (normalized.bounds.x2 - normalized.bounds.x1 + 1)
            * (normalized.bounds.y2 - normalized.bounds.y1 + 1) * normalized.heightMeters
    end
    for _, point in ipairs(type(definition.vents) == "table" and definition.vents or {}) do
        normalized.vents[#normalized.vents + 1] = copyPoint(point)
    end
    for _, connection in ipairs(type(definition.connections) == "table" and definition.connections or {}) do
        if type(connection) == "string" and connection ~= definition.id then
            normalized.connections[#normalized.connections + 1] = connection
        end
    end
    return normalized
end

function RoomRegistry.register(definition)
    local normalized, reason = normalizeDefinition(definition)
    if not normalized then return false, reason end
    if RoomRegistry.definitions[normalized.id] == nil then
        RoomRegistry.order[#RoomRegistry.order + 1] = normalized.id
    end
    RoomRegistry.definitions[normalized.id] = normalized
    return true
end

function RoomRegistry.registerMany(definitions)
    local accepted, rejected = 0, {}
    for _, definition in ipairs(type(definitions) == "table" and definitions or {}) do
        local ok, reason = RoomRegistry.register(definition)
        if ok then accepted = accepted + 1 else rejected[#rejected + 1] = reason end
    end
    return accepted, rejected
end

function RoomRegistry.get(id)
    return RoomRegistry.definitions[id]
end

function RoomRegistry.all()
    local result = {}
    for _, id in ipairs(RoomRegistry.order) do result[#result + 1] = RoomRegistry.definitions[id] end
    return result
end

function RoomRegistry.contains(definition, x, y, z)
    local bounds = definition and definition.bounds
    if not bounds then return false end
    return math.floor(number(z, 0)) == bounds.z
        and number(x, -1000000000) >= bounds.x1 and number(x, 1000000000) <= bounds.x2 + 0.9999
        and number(y, -1000000000) >= bounds.y1 and number(y, 1000000000) <= bounds.y2 + 0.9999
end

function RoomRegistry.find(x, y, z)
    local best, bestArea = nil, math.huge
    for _, definition in ipairs(RoomRegistry.all()) do
        if RoomRegistry.contains(definition, x, y, z) then
            local area = (definition.bounds.x2 - definition.bounds.x1 + 1)
                * (definition.bounds.y2 - definition.bounds.y1 + 1)
            if area < bestArea then best, bestArea = definition, area end
        end
    end
    return best
end

function RoomRegistry.ensureState(roomStates, baselineCo2)
    roomStates = type(roomStates) == "table" and roomStates or {}
    for _, definition in ipairs(RoomRegistry.all()) do
        local room = roomStates[definition.id]
        if type(room) ~= "table" then room = {}; roomStates[definition.id] = room end
        room.id = definition.id
        room.label = definition.label
        room.kind = definition.kind
        room.bounds = definition.bounds
        room.volumeM3 = number(room.volumeM3, definition.volumeM3, 1)
        room.ventWeight = number(room.ventWeight, definition.ventWeight, 0)
        room.leakRate = number(room.leakRate, definition.leakRate, 0)
        room.sealed = room.sealed ~= false
        room.occupants = math.max(0, math.floor(number(room.occupants, 0, 0)))
        room.co2 = number(room.co2, baselineCo2 or 420, baselineCo2 or 420)
        room.contamination = math.min(1, number(room.contamination, 0, 0))
        room.airflowM3PerMinute = number(room.airflowM3PerMinute, 0, 0)
        room.status = type(room.status) == "string" and room.status or "operational"
    end
    return roomStates
end

BunkerCampaign.RoomRegistry = RoomRegistry
return RoomRegistry
