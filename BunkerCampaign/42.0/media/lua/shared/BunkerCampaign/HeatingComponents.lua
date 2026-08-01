require "BunkerCampaign/Util"

BunkerCampaign = BunkerCampaign or {}

local Util = BunkerCampaign.Util
local HeatingComponents = {}

local definitions = {
    controller = {
        id="controller", label="Heating controller", role="control",
        x=9963, y=12627, z=-4, sprite="appliances_com_01_52",
        initialCondition=0.78, wearPerOperatingMinute=0.000003,
        skills={ Electricity=3 }, tools={ "Base.Screwdriver" },
        materials={ ["Base.ElectronicsScrap"]=2, ["Base.ElectricWire"]=1 },
        temporaryMaterials={ ["Base.ElectronicsScrap"]=1, ["Base.Wire"]=1 },
        faults={ minor="sensor_drift", major="controller_offline" },
    },
    heat_exchanger = {
        id="heat_exchanger", label="Heat exchanger", role="heat_source",
        x=9968, y=12633, z=-4, sprite="industry_02_17",
        initialCondition=0.82, wearPerOperatingMinute=0.000010,
        skills={ Mechanics=3, MetalWelding=2 },
        tools={ "Base.BlowTorch", "Base.WeldingMask" },
        materials={ ["Base.SmallSheetMetal"]=1, ["Base.ScrapMetal"]=2 },
        temporaryMaterials={ ["Base.DuctTape"]=1, ["Base.ScrapMetal"]=1 },
        faults={ minor="exchanger_fouling", major="exchanger_trip" },
    },
    circulation_blower = {
        id="circulation_blower", label="Circulation blower", role="circulation",
        x=9967, y=12635, z=-4, sprite="rooftop_furniture_5",
        initialCondition=0.80, wearPerOperatingMinute=0.000008,
        skills={ Mechanics=3, Electricity=1 },
        tools={ "Base.Wrench", "Base.Screwdriver" },
        materials={ ["Base.ScrapMetal"]=2, ["Base.Wire"]=1 },
        temporaryMaterials={ ["Base.DuctTape"]=1, ["Base.Wire"]=1 },
        faults={ minor="worn_bearing", major="blower_seized" },
    },
    supply_valve = {
        id="supply_valve", label="Heating supply valve", role="valve",
        x=9966, y=12637, z=-4, sprite="industry_02_55",
        initialCondition=0.86, wearPerOperatingMinute=0.000002, normallyOpen=true,
        skills={ Mechanics=2, MetalWelding=1 }, tools={ "Base.Wrench" },
        materials={ ["Base.MetalPipe"]=1, ["Base.ScrapMetal"]=1 },
        temporaryMaterials={ ["Base.DuctTape"]=1, ["Base.Wire"]=1 },
        faults={ minor="valve_stuck_open", major="valve_stuck_closed" },
    },
    return_valve = {
        id="return_valve", label="Heating return valve", role="valve",
        x=9966, y=12639, z=-4, sprite="industry_02_62",
        initialCondition=0.86, wearPerOperatingMinute=0.000002, normallyOpen=true,
        skills={ Mechanics=2, MetalWelding=1 }, tools={ "Base.Wrench" },
        materials={ ["Base.MetalPipe"]=1, ["Base.ScrapMetal"]=1 },
        temporaryMaterials={ ["Base.DuctTape"]=1, ["Base.Wire"]=1 },
        faults={ minor="valve_stuck_open", major="valve_stuck_closed" },
    },
    pipe_manifold = {
        id="pipe_manifold", label="Heating pipe manifold", role="distribution",
        x=9966, y=12640, z=-4, sprite="industry_02_16",
        initialCondition=0.86, initialIntegrity=0.90,
        wearPerOperatingMinute=0.000006,
        skills={ Mechanics=2, MetalWelding=2 },
        tools={ "Base.BlowTorch", "Base.WeldingMask" },
        materials={ ["Base.MetalPipe"]=1, ["Base.SmallSheetMetal"]=1 },
        temporaryMaterials={ ["Base.DuctTape"]=1, ["Base.ScrapMetal"]=1 },
        faults={ minor="coolant_leak", major="pipe_rupture" },
    },
}

local orderedIds = {
    "controller", "heat_exchanger", "circulation_blower",
    "supply_valve", "return_valve", "pipe_manifold",
}

local knownFaults = { none=true }
for _, definition in pairs(definitions) do
    knownFaults[definition.faults.minor] = true
    knownFaults[definition.faults.major] = true
end

function HeatingComponents.get(id)
    return type(id) == "string" and definitions[id] or nil
end

function HeatingComponents.all()
    return definitions
end

function HeatingComponents.orderedIds()
    return orderedIds
end

function HeatingComponents.isKnownFault(fault)
    return knownFaults[fault] == true
end

function HeatingComponents.faultSeverity(id, fault)
    local definition = definitions[id]
    if fault == nil or fault == "none" then return "none" end
    if definition and fault == definition.faults.minor then return "minor" end
    return "major"
end

function HeatingComponents.createComponentState(definition)
    return {
        id=definition.id,
        condition=definition.initialCondition,
        integrity=definition.initialIntegrity,
        fault="none",
        diagnosed=false,
        temporaryRepair=false,
        open=definition.normallyOpen,
        outputKw=definition.id == "heat_exchanger" and 0 or nil,
    }
end

function HeatingComponents.createDefaultState()
    local result = {}
    for _, id in ipairs(orderedIds) do
        result[id] = HeatingComponents.createComponentState(definitions[id])
    end
    return result
end

function HeatingComponents.normalizeComponent(id, component)
    local definition = definitions[id]
    if not definition then return false end
    local changed = false
    if type(component) ~= "table" then return false end
    local values = {
        id=id,
        condition=Util.numberOr(component.condition, definition.initialCondition, 0, 1),
        fault=type(component.fault) == "string" and component.fault ~= ""
            and component.fault or "none",
        diagnosed=component.diagnosed == true,
        temporaryRepair=component.temporaryRepair == true,
    }
    if definition.initialIntegrity then
        values.integrity = Util.numberOr(component.integrity,
            definition.initialIntegrity, 0, 1)
    end
    if definition.normallyOpen ~= nil then
        values.open = Util.booleanOr(component.open, definition.normallyOpen)
    end
    if id == "heat_exchanger" then
        values.outputKw = math.max(0, tonumber(component.outputKw) or 0)
    end
    for key, value in pairs(values) do
        if component[key] ~= value then component[key] = value; changed = true end
    end
    return changed
end

function HeatingComponents.matchCoordinates(x, y, z, spriteName)
    x, y, z = math.floor(tonumber(x) or -999999),
        math.floor(tonumber(y) or -999999), math.floor(tonumber(z) or -999999)
    for _, id in ipairs(orderedIds) do
        local definition = definitions[id]
        if x == definition.x and y == definition.y and z == definition.z
            and (spriteName == nil or spriteName == definition.sprite) then
            return definition
        end
    end
    return nil
end

function HeatingComponents.matchObject(object)
    if not object or type(object.getSquare) ~= "function" then return nil end
    local square = object:getSquare()
    if not square then return nil end
    local sprite = type(object.getSprite) == "function" and object:getSprite() or nil
    local spriteName = sprite and type(sprite.getName) == "function" and sprite:getName() or nil
    return HeatingComponents.matchCoordinates(
        square:getX(), square:getY(), square:getZ(), spriteName)
end

function HeatingComponents.isNear(player, definition, distance)
    if not player or not definition then return false end
    distance = tonumber(distance) or 2.5
    if math.floor(player:getZ()) ~= definition.z then return false end
    local dx, dy = player:getX() - definition.x, player:getY() - definition.y
    return dx * dx + dy * dy <= distance * distance
end

BunkerCampaign.HeatingComponents = HeatingComponents
return HeatingComponents
