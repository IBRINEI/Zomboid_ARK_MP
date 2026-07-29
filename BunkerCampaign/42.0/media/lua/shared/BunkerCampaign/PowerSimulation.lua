require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local Util = BunkerCampaign.Util
local PowerSimulation = {}

local function defaultGenerator(id, requested, fuel, condition, coolant, lubricant, maxOutputKw)
    return {
        id = id,
        requested = requested,
        running = false,
        status = "offline",
        fuel = fuel,
        condition = condition,
        coolant = coolant,
        lubricant = lubricant,
        maxOutputKw = maxOutputKw,
        availableKw = 0,
        loadKw = 0,
    }
end

local function defaultConsumer(id, requested, demandKw, priority, batteryEligible)
    return {
        id = id,
        requested = requested,
        demandKw = demandKw,
        priority = priority,
        batteryEligible = batteryEligible,
        allocated = false,
        source = "off",
    }
end

function PowerSimulation.createDefault()
    local rules = Constants.POWER
    return {
        status = "offline",
        gridOnline = false,
        emergencyMode = false,
        availableCapacityKw = 0,
        demandKw = 0,
        allocatedKw = 0,
        shedKw = 0,
        battery = {
            charge = rules.BATTERY_INITIAL_CHARGE,
            capacityKwh = rules.BATTERY_CAPACITY_KWH,
            outputKw = 0,
            chargingKw = 0,
        },
        generators = {
            main = defaultGenerator("main", true, 0.87, 0.81, 0.72, 0.83, rules.MAIN_GENERATOR_MAX_KW),
            backup = defaultGenerator("backup", false, 0.50, 0.90, 0.90, 0.90, rules.BACKUP_GENERATOR_MAX_KW),
        },
        consumers = {
            emergency_lighting = defaultConsumer("emergency_lighting", true, 0.35, 100, true),
            control = defaultConsumer("control", true, 0.15, 95, true),
            ventilation = defaultConsumer("ventilation", true, 3.50, 90, false),
            water = defaultConsumer("water", true, 1.50, 80, false),
            decontamination = defaultConsumer("decontamination", false, 2.50, 75, false),
            main_lighting = defaultConsumer("main_lighting", true, 1.00, 70, false),
        },
    }
end

local function copyMissing(target, defaults)
    local changed = false
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
            changed = true
        end
    end
    return changed
end

local function normalizeGenerator(generator, defaults)
    local changed = copyMissing(generator, defaults)
    local values = {
        requested = Util.booleanOr(generator.requested, defaults.requested),
        running = Util.booleanOr(generator.running, false),
        fuel = Util.numberOr(generator.fuel, defaults.fuel, 0, 1),
        condition = Util.numberOr(generator.condition, defaults.condition, 0, 1),
        coolant = Util.numberOr(generator.coolant, defaults.coolant, 0, 1),
        lubricant = Util.numberOr(generator.lubricant, defaults.lubricant, 0, 1),
        maxOutputKw = Util.numberOr(generator.maxOutputKw, defaults.maxOutputKw, 0, Constants.POWER.MAX_GENERATOR_OUTPUT_KW),
        availableKw = Util.numberOr(generator.availableKw, 0, 0, Constants.POWER.MAX_GENERATOR_OUTPUT_KW),
        loadKw = Util.numberOr(generator.loadKw, 0, 0, Constants.POWER.MAX_GENERATOR_OUTPUT_KW),
    }
    values.status = Constants.VALID_GENERATOR_STATUS[generator.status] and generator.status or defaults.status
    values.id = defaults.id
    for key, value in pairs(values) do
        if generator[key] ~= value then generator[key] = value; changed = true end
    end
    return changed
end

local function normalizeConsumer(consumer, defaults)
    local changed = copyMissing(consumer, defaults)
    local values = {
        id = defaults.id,
        requested = Util.booleanOr(consumer.requested, defaults.requested),
        demandKw = Util.numberOr(consumer.demandKw, defaults.demandKw, 0, Constants.POWER.MAX_CONSUMER_DEMAND_KW),
        priority = math.floor(Util.numberOr(consumer.priority, defaults.priority, 0, 1000)),
        batteryEligible = Util.booleanOr(consumer.batteryEligible, defaults.batteryEligible),
        allocated = Util.booleanOr(consumer.allocated, false),
    }
    values.source = Constants.VALID_POWER_SOURCE[consumer.source] and consumer.source or "off"
    for key, value in pairs(values) do
        if consumer[key] ~= value then consumer[key] = value; changed = true end
    end
    return changed
end

function PowerSimulation.normalize(power)
    local defaults = PowerSimulation.createDefault()
    local changed = copyMissing(power, defaults)
    if type(power.battery) ~= "table" then power.battery = {}; changed = true end
    if type(power.generators) ~= "table" then power.generators = {}; changed = true end
    if type(power.consumers) ~= "table" then power.consumers = {}; changed = true end

    for id, generatorDefaults in pairs(defaults.generators) do
        if type(power.generators[id]) ~= "table" then power.generators[id] = {}; changed = true end
        if normalizeGenerator(power.generators[id], generatorDefaults) then changed = true end
    end
    for id, consumerDefaults in pairs(defaults.consumers) do
        if type(power.consumers[id]) ~= "table" then power.consumers[id] = {}; changed = true end
        if normalizeConsumer(power.consumers[id], consumerDefaults) then changed = true end
    end

    local battery = power.battery
    local batteryValues = {
        charge = Util.numberOr(battery.charge, defaults.battery.charge, 0, 1),
        capacityKwh = Util.numberOr(battery.capacityKwh, defaults.battery.capacityKwh, 0.01, Constants.POWER.MAX_BATTERY_CAPACITY_KWH),
        outputKw = Util.numberOr(battery.outputKw, 0, 0, Constants.POWER.BATTERY_MAX_OUTPUT_KW),
        chargingKw = Util.numberOr(battery.chargingKw, 0, 0, Constants.POWER.BATTERY_MAX_CHARGE_KW),
    }
    for key, value in pairs(batteryValues) do
        if battery[key] ~= value then battery[key] = value; changed = true end
    end

    local scalarValues = {
        gridOnline = Util.booleanOr(power.gridOnline, false),
        emergencyMode = Util.booleanOr(power.emergencyMode, false),
        availableCapacityKw = Util.numberOr(power.availableCapacityKw, 0, 0, Constants.POWER.MAX_TOTAL_POWER_KW),
        demandKw = Util.numberOr(power.demandKw, 0, 0, Constants.POWER.MAX_TOTAL_POWER_KW),
        allocatedKw = Util.numberOr(power.allocatedKw, 0, 0, Constants.POWER.MAX_TOTAL_POWER_KW),
        shedKw = Util.numberOr(power.shedKw, 0, 0, Constants.POWER.MAX_TOTAL_POWER_KW),
    }
    scalarValues.status = Constants.VALID_POWER_STATUS[power.status] and power.status or defaults.status
    for key, value in pairs(scalarValues) do
        if power[key] ~= value then power[key] = value; changed = true end
    end
    return changed
end

local function generatorStatus(generator)
    if generator.fuel <= 0 then return "exhausted" end
    if generator.condition <= 0.05 then return "failed" end
    if generator.running then
        if generator.condition < 0.50 or generator.coolant < 0.20 or generator.lubricant < 0.20 then return "degraded" end
        return "operational"
    end
    return "offline"
end

local function sortedConsumers(consumers)
    local result = {}
    for _, consumer in pairs(consumers) do result[#result + 1] = consumer end
    table.sort(result, function(left, right)
        if left.priority == right.priority then return left.id < right.id end
        return left.priority > right.priority
    end)
    return result
end

local function sortedGenerators(generators)
    local result = {}
    if generators.main then result[#result + 1] = generators.main end
    if generators.backup then result[#result + 1] = generators.backup end
    return result
end

function PowerSimulation.update(power, deltaMinutes)
    PowerSimulation.normalize(power)
    deltaMinutes = Util.numberOr(deltaMinutes, 1, 0, 60)
    local rules = Constants.POWER
    local previousStatus = power.status
    local previousAllocations = {}
    for id, consumer in pairs(power.consumers) do previousAllocations[id] = consumer.allocated end

    local runningGenerators = {}
    local available = 0
    for _, generator in ipairs(sortedGenerators(power.generators)) do
        generator.running = generator.requested and generator.fuel > 0 and generator.condition > 0.05
        generator.availableKw = generator.running and generator.maxOutputKw * math.max(generator.condition, 0.25) or 0
        generator.loadKw = 0
        generator.status = generatorStatus(generator)
        if generator.running then
            runningGenerators[#runningGenerators + 1] = generator
            available = available + generator.availableKw
        end
    end

    local generatorRemaining = available
    local batteryRemainingKw = 0
    if #runningGenerators == 0 and power.battery.charge > 0 then
        batteryRemainingKw = rules.BATTERY_MAX_OUTPUT_KW
    end
    local generatorLoad = 0
    local batteryLoad = 0
    local demand = 0
    local shed = 0
    for _, consumer in ipairs(sortedConsumers(power.consumers)) do
        consumer.allocated = false
        consumer.source = "off"
        local requestNow = consumer.requested
        -- Red emergency fixtures are intentionally dark while generators feed
        -- the main grid.  They become a battery load only during a grid outage.
        if consumer.id == "emergency_lighting" and #runningGenerators > 0 then requestNow = false end
        if requestNow then
            demand = demand + consumer.demandKw
            if consumer.demandKw <= generatorRemaining + 0.000001 then
                consumer.allocated = true
                consumer.source = "generator"
                generatorRemaining = generatorRemaining - consumer.demandKw
                generatorLoad = generatorLoad + consumer.demandKw
            elseif consumer.batteryEligible and consumer.demandKw <= batteryRemainingKw + 0.000001 then
                consumer.allocated = true
                consumer.source = "battery"
                batteryRemainingKw = batteryRemainingKw - consumer.demandKw
                batteryLoad = batteryLoad + consumer.demandKw
            else
                consumer.source = "shed"
                shed = shed + consumer.demandKw
            end
        end
    end

    if available > 0 then
        for _, generator in ipairs(runningGenerators) do
            generator.loadKw = generatorLoad * (generator.availableKw / available)
        end
    end

    local battery = power.battery
    battery.outputKw = batteryLoad
    battery.chargingKw = 0
    if deltaMinutes > 0 then
        if batteryLoad > 0 then
            local usedKwh = batteryLoad * deltaMinutes / 60
            battery.charge = math.max(0, battery.charge - usedKwh / battery.capacityKwh)
        elseif available > generatorLoad and battery.charge < 1 then
            battery.chargingKw = math.min(rules.BATTERY_MAX_CHARGE_KW, available - generatorLoad)
            local gainedKwh = battery.chargingKw * rules.BATTERY_CHARGE_EFFICIENCY * deltaMinutes / 60
            battery.charge = math.min(1, battery.charge + gainedKwh / battery.capacityKwh)
        end

        for _, generator in ipairs(runningGenerators) do
            local fuelPercent = generator.loadKw * rules.FUEL_PERCENT_PER_KW_MINUTE * deltaMinutes
            generator.fuel = math.max(0, generator.fuel - fuelPercent / 100)
            generator.coolant = math.max(0, generator.coolant - rules.COOLANT_PERCENT_PER_MINUTE * deltaMinutes / 100)
            generator.lubricant = math.max(0, generator.lubricant - rules.LUBRICANT_PERCENT_PER_MINUTE * deltaMinutes / 100)
            local conditionLoss = rules.CONDITION_PERCENT_PER_MINUTE
            if generator.coolant < 0.10 then conditionLoss = conditionLoss + rules.LOW_FLUID_CONDITION_PENALTY end
            if generator.lubricant < 0.10 then conditionLoss = conditionLoss + rules.LOW_FLUID_CONDITION_PENALTY end
            generator.condition = math.max(0, generator.condition - conditionLoss * deltaMinutes / 100)
            generator.status = generatorStatus(generator)
        end
    end

    power.gridOnline = #runningGenerators > 0
    power.emergencyMode = #runningGenerators == 0 and batteryLoad > 0
    power.availableCapacityKw = available
    power.demandKw = demand
    power.allocatedKw = generatorLoad + batteryLoad
    power.shedKw = shed
    if power.emergencyMode then
        power.status = "emergency"
    elseif not power.gridOnline then
        power.status = "offline"
    elseif shed > 0 then
        power.status = "degraded"
    else
        power.status = "operational"
    end

    local allocationChanges = {}
    for id, consumer in pairs(power.consumers) do
        if previousAllocations[id] ~= consumer.allocated then allocationChanges[#allocationChanges + 1] = id end
    end
    table.sort(allocationChanges)
    return {
        statusChanged = previousStatus ~= power.status,
        previousStatus = previousStatus,
        allocationChanges = allocationChanges,
    }
end

BunkerCampaign.PowerSimulation = PowerSimulation
return PowerSimulation
