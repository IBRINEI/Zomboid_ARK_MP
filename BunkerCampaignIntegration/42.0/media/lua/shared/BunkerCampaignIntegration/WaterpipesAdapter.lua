require "BunkerCampaign/Util"
require "BunkerCampaignIntegration/Constants"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local Util = BunkerCampaign.Util
local Constants = BunkerCampaignIntegration.Constants
local WaterpipesAdapter = {}

local function coordsId(coords)
    return tostring(coords.x) .. "-" .. tostring(coords.y) .. "-" .. tostring(coords.z)
end

local function isInsideBunker(entry)
    if type(entry) ~= "table" then return false end
    local bounds = Constants.BUNKER_BOUNDS
    return Util.isFiniteNumber(entry.x)
        and Util.isFiniteNumber(entry.y)
        and Util.isFiniteNumber(entry.z)
        and entry.x >= bounds.x1 and entry.x <= bounds.x2
        and entry.y >= bounds.y1 and entry.y <= bounds.y2
        and bounds.levels[entry.z] == true
end

local function normalizePercent(value)
    return Util.clamp(Util.numberOr(value, 0, 0, 100) / 100, 0, 1)
end

local function physicalReceiver(record)
    if not getCell or type(WPIso) ~= "table" or type(WPIso.GetBarrel) ~= "function" then return nil end
    local cell = getCell()
    local square = cell and cell:getGridSquare(record.x, record.y, record.z) or nil
    return square and WPIso.GetBarrel(square) or nil
end

local function physicalWater(record)
    local object = physicalReceiver(record)
    if not object then return nil, 0, 0, nil end
    local amount, capacity
    if type(WPIso.GetWaterStatus) == "function" then
        -- WaterPipes treats sinks with pre-shutoff sprite values, post-shutoff
        -- ModData values, and real fluid containers differently.  Its own
        -- accessor is the only reliable way to cover all three cases.
        amount, capacity = WPIso.GetWaterStatus(object)
    else
        amount = object.getFluidAmount and tonumber(object:getFluidAmount()) or 0
        capacity = object.getFluidCapacity and tonumber(object:getFluidCapacity()) or nil
    end
    local md = object.getModData and object:getModData() or nil
    -- WaterPipes reads pre-shutoff sink amounts from sprite properties.  Those
    -- values are strings in the live game even though container-backed values
    -- are numbers, so normalize before any arithmetic or comparison.
    amount = tonumber(amount) or 0
    capacity = tonumber(capacity) or tonumber(md and (md.waterMaxAmount or md.waterMax)) or 0
    local medium = nil
    if amount > 0 then
        local container = object.getFluidContainer and object:getFluidContainer() or nil
        local primary = container and container.getPrimaryFluid and container:getPrimaryFluid() or nil
        local primaryName = primary and primary.getFluidTypeString and primary:getFluidTypeString() or nil
        if primaryName ~= nil then primaryName = tostring(primaryName) end
        if primaryName == "TaintedWater" or primaryName == "Water" then
            medium = primaryName
        elseif object.isTaintedWater and object:isTaintedWater() then
            medium = "TaintedWater"
        elseif record.m == "TaintedWater" or record.m == "Water" then
            medium = record.m
        elseif md and (md.BunkerCampaignWaterMedium == "TaintedWater"
            or md.BunkerCampaignWaterMedium == "Water") then
            medium = md.BunkerCampaignWaterMedium
        else
            medium = "Water"
        end
        -- WaterPipes clears the sprite taint flag after its pending buffer is
        -- transferred.  Preserve the actual receiver medium instead.
        if md then md.BunkerCampaignWaterMedium = medium end
        local sprite = object.getSprite and object:getSprite() or nil
        local properties = sprite and sprite.getProperties and sprite:getProperties() or nil
        if properties and IsoFlagType and IsoFlagType.taintedWater then
            if medium == "TaintedWater" then properties:set(IsoFlagType.taintedWater)
            else properties:unset(IsoFlagType.taintedWater) end
        end
    elseif md then
        md.BunkerCampaignWaterMedium = nil
    end
    return object, math.max(0, amount), math.max(0, capacity), medium
end

local function setPhysicalWater(object, medium, amount, capacity)
    if not object then return false end
    amount, capacity = math.max(0, tonumber(amount) or 0), math.max(0, tonumber(capacity) or 0)
    if object.emptyFluid then object:emptyFluid()
    elseif object.getFluidContainer and object:getFluidContainer() then object:getFluidContainer():Empty() end
    local fluidType = FluidType and FluidType[medium] or nil
    if amount > 0 and fluidType and object.addFluid then
        object:addFluid(fluidType, amount)
    end
    local md = object.getModData and object:getModData() or nil
    if md then
        md.waterAmount = amount
        if capacity > 0 then md.waterMaxAmount = capacity end
        md.BunkerCampaignWaterMedium = amount > 0 and medium or nil
    end
    local sprite = object.getSprite and object:getSprite() or nil
    local properties = sprite and sprite.getProperties and sprite:getProperties() or nil
    if properties and IsoFlagType and IsoFlagType.taintedWater then
        if amount > 0 and medium == "TaintedWater" then
            properties:set(IsoFlagType.taintedWater)
        else
            properties:unset(IsoFlagType.taintedWater)
        end
    end
    if object.transmitModData then object:transmitModData() end
    if object.sync then object:sync() end
    return true
end

function WaterpipesAdapter.prepareCollections(gmd)
    if type(gmd) ~= "table" then return false end
    local changed = false
    local names = { "Pumps", "Pipes", "Valves", "Flowmeters", "Barrels", "Sprinklers", "Buildings" }
    for _, name in ipairs(names) do
        if type(gmd[name]) ~= "table" then
            gmd[name] = {}
            changed = true
        end
    end
    return changed
end

function WaterpipesAdapter.isPhysicalPumpLoaded()
    if not getCell or type(WPIso) ~= "table" or type(WPIso.GetPump) ~= "function" then return false end
    local coords = Constants.BUNKER_WATER_PUMP
    local cell = getCell()
    if not cell then return false end
    local square = cell:getGridSquare(coords.x, coords.y, coords.z)
    return square ~= nil and WPIso.GetPump(square) ~= nil
end

function WaterpipesAdapter.ensureBunkerPump(gmd, physicalPresent, activeDefault)
    if type(gmd) ~= "table" then return nil, false end
    local changed = WaterpipesAdapter.prepareCollections(gmd)
    local coords = Constants.BUNKER_WATER_PUMP
    local key = coordsId(coords)
    local pump = gmd.Pumps[key]

    if type(pump) ~= "table" then
        if physicalPresent ~= true then return nil, changed end
        pump = {
            x = coords.x,
            y = coords.y,
            z = coords.z,
            efficiency = 100,
            filter = 100,
            active = activeDefault ~= false,
            burn = false,
            source = "TaintedWater",
        }
        gmd.Pumps[key] = pump
        return pump, true
    end

    if pump.x ~= coords.x then pump.x = coords.x; changed = true end
    if pump.y ~= coords.y then pump.y = coords.y; changed = true end
    if pump.z ~= coords.z then pump.z = coords.z; changed = true end
    if not Util.isFiniteNumber(pump.efficiency) then pump.efficiency = 100; changed = true end
    if not Util.isFiniteNumber(pump.filter) then pump.filter = 0; changed = true end
    if type(activeDefault) == "boolean" and pump.active ~= activeDefault then
        pump.active = activeDefault
        changed = true
    elseif type(pump.active) ~= "boolean" then
        pump.active = false
        changed = true
    end
    if type(pump.burn) ~= "boolean" then pump.burn = false; changed = true end
    if pump.source == nil then pump.source = "TaintedWater"; changed = true end
    return pump, changed
end

function WaterpipesAdapter.setBunkerPumpOperating(gmd, operating, selectedSource, bypass)
    if type(gmd) ~= "table" or type(gmd.Pumps) ~= "table" then return false, "pump_missing" end
    local pump = gmd.Pumps[coordsId(Constants.BUNKER_WATER_PUMP)]
    if type(pump) ~= "table" then return false, "pump_missing" end
    local changed = false
    operating = operating == true
    if pump.active ~= operating then pump.active = operating; changed = true end
    local medium = "TaintedWater"
    if selectedSource == "portable_supply" then medium = "Water" end
    if pump.source ~= medium then pump.source = medium; changed = true end
    pump.BunkerCampaignSource = type(selectedSource) == "string" and selectedSource or "underground_well"
    if bypass == true then
        if Util.isFiniteNumber(pump.filter) and pump.filter > 0 then
            pump.BunkerCampaignStoredFilter = math.max(tonumber(pump.BunkerCampaignStoredFilter) or 0, pump.filter)
            pump.filter = 0
            changed = true
        end
        pump.BunkerCampaignBypass = true
    else
        if pump.BunkerCampaignBypass == true and Util.isFiniteNumber(pump.BunkerCampaignStoredFilter) then
            pump.filter = Util.clamp(pump.BunkerCampaignStoredFilter, 0, 100)
            pump.BunkerCampaignStoredFilter = nil
            changed = true
        end
        pump.BunkerCampaignBypass = false
    end
    return changed
end

local function registerBuildingReceivers(gmd, building, buildingId)
    if not building or not buildingId or type(WPIso.GetBarrel) ~= "function" or type(WPIso.GetWaterStatus) ~= "function" then
        return false
    end
    local def = building:getDef()
    if not def then return false end

    local changed = false
    local cell = getCell()
    for z = def:getMinLevel(), def:getMaxLevel() do
        for y = def:getY(), def:getY2() do
            for x = def:getX(), def:getX2() do
                local square = cell:getGridSquare(x, y, z)
                if square and not square:isOutside() then
                    local object = WPIso.GetBarrel(square)
                    if object then
                        local key = tostring(x) .. "-" .. tostring(y) .. "-" .. tostring(z)
                        if type(gmd.Barrels[key]) ~= "table" then
                            local water, capacity = WPIso.GetWaterStatus(object)
                            gmd.Barrels[key] = {
                                x = x,
                                y = y,
                                z = z,
                                w = 0,
                                wmax = math.max(0, tonumber(capacity) or 0) * 100,
                                bid = buildingId,
                            }
                            changed = true
                        elseif gmd.Barrels[key].bid ~= buildingId then
                            gmd.Barrels[key].bid = buildingId
                            changed = true
                        end
                    end
                end
            end
        end
    end
    return changed
end

function WaterpipesAdapter.ensureBunkerInfrastructure(gmd)
    if type(gmd) ~= "table" or not getCell or type(WPIso) ~= "table" then return false end
    local changed = WaterpipesAdapter.prepareCollections(gmd)
    local cell = getCell()
    if not cell then return changed end

    if type(WPIso.GetPipe) == "function" then
        for _, pipe in ipairs(Constants.BUNKER_WATER_PIPES) do
            local square = cell:getGridSquare(pipe.x, pipe.y, pipe.z)
            if square and WPIso.GetPipe(square) then
                local key = coordsId(pipe)
                local record = gmd.Pipes[key]
                if type(record) ~= "table" then
                    gmd.Pipes[key] = { x = pipe.x, y = pipe.y, z = pipe.z, s = pipe.shape, v = 0, w = 0 }
                    changed = true
                elseif record.s ~= pipe.shape then
                    record.s = pipe.shape
                    changed = true
                end
            end
        end
    end

    if type(WPIso.GetFlowmeter) == "function" then
        local meterCoords = Constants.BUNKER_WATER_FLOWMETER
        local square = cell:getGridSquare(meterCoords.x, meterCoords.y, meterCoords.z)
        if square and WPIso.GetFlowmeter(square) then
            local key = coordsId(meterCoords)
            if type(gmd.Flowmeters[key]) ~= "table" then
                gmd.Flowmeters[key] = { x = meterCoords.x, y = meterCoords.y, z = meterCoords.z, f = 0 }
                changed = true
            end
        end
    end

    local connection = Constants.BUNKER_WATER_BUILDING_CONNECTION
    local square = cell:getGridSquare(connection.x, connection.y, connection.z)
    if square then
        local building = square:getBuilding()
        local def = building and building:getDef() or nil
        local buildingId = def and def:getIDString() or nil
        if buildingId then
            local key = coordsId(connection)
            local firstRegistration = type(gmd.Buildings[key]) ~= "table"
            if firstRegistration then
                gmd.Buildings[key] = { x = connection.x, y = connection.y, z = connection.z, bid = buildingId }
                changed = true
            elseif gmd.Buildings[key].bid ~= buildingId then
                gmd.Buildings[key].bid = buildingId
                changed = true
            end
            if firstRegistration and registerBuildingReceivers(gmd, building, buildingId) then changed = true end
        end
    end
    return changed
end

local function sortedBunkerBarrels(gmd)
    local result = {}
    local barrels = type(gmd) == "table" and type(gmd.Barrels) == "table" and gmd.Barrels or {}
    for key, barrel in pairs(barrels) do
        if isInsideBunker(barrel) then
            result[#result + 1] = { key=tostring(key), barrel=barrel }
        end
    end
    table.sort(result, function(left, right) return left.key < right.key end)
    return result
end

function WaterpipesAdapter.availableBunkerWater(gmd, cleanOnly)
    local liters = 0
    for _, entry in ipairs(sortedBunkerBarrels(gmd)) do
        local barrel = entry.barrel
        local _, physicalAmount, _, physicalMedium = physicalWater(barrel)
        local pendingAmount = Util.numberOr(barrel.w, 0, 0, BunkerCampaign.Constants.WATER.MAX_STORAGE) / 100
        if not cleanOnly or barrel.m == "Water" then liters = liters + pendingAmount end
        if not cleanOnly or physicalMedium == "Water" then liters = liters + physicalAmount end
    end
    return liters
end

function WaterpipesAdapter.consumeBunkerWater(gmd, liters, cleanOnly)
    liters = Util.numberOr(liters, 0, 0, BunkerCampaign.Constants.WATER.MAX_STORAGE)
    local required = liters
    if WaterpipesAdapter.availableBunkerWater(gmd, cleanOnly == true) + 0.0001 < required then
        return false, 0
    end

    local remaining = required
    for _, entry in ipairs(sortedBunkerBarrels(gmd)) do
        if remaining <= 0 then break end
        local barrel = entry.barrel
        local pending = Util.numberOr(barrel.w, 0, 0, BunkerCampaign.Constants.WATER.MAX_STORAGE) / 100
        if not cleanOnly or barrel.m == "Water" then
            local used = math.min(pending, remaining)
            barrel.w = math.max(0, (pending - used) * 100)
            if barrel.w <= 0.0001 then barrel.w = 0; barrel.m = nil end
            remaining = remaining - used
        end
        if remaining > 0 then
            local object, physicalAmount, capacity, physicalMedium = physicalWater(barrel)
            if object and (not cleanOnly or physicalMedium == "Water") then
                local used = math.min(physicalAmount, remaining)
                setPhysicalWater(object, physicalMedium or "Water", physicalAmount - used, capacity)
                remaining = remaining - used
            end
        end
    end
    return remaining <= 0.0001, required - remaining
end

function WaterpipesAdapter.fillBunkerWater(gmd)
    local found, changed = WaterpipesAdapter.setBunkerStorageForQa(gmd, "Water", 1)
    return found and changed
end

function WaterpipesAdapter.setBunkerStorageForQa(gmd, medium, fillFraction)
    fillFraction = Util.numberOr(fillFraction, 0, 0, 1)
    if medium ~= nil and medium ~= "Water" and medium ~= "TaintedWater" then return false end
    local changed, found = false, false
    for _, entry in ipairs(sortedBunkerBarrels(gmd)) do
        found = true
        local barrel = entry.barrel
        local object, _, physicalCapacity = physicalWater(barrel)
        local rawCapacity = Util.numberOr(barrel.wmax, 0, 0, BunkerCampaign.Constants.WATER.MAX_STORAGE)
        local capacity = physicalCapacity > 0 and physicalCapacity or rawCapacity / 100
        local amount = capacity * fillFraction
        local targetMedium = amount > 0 and medium or nil
        if object then
            setPhysicalWater(object, targetMedium or "Water", amount, capacity)
            barrel.w, barrel.m = 0, nil
            changed = true
        else
            local rawAmount = amount * 100
            if barrel.w ~= rawAmount or barrel.m ~= targetMedium then
                barrel.w = rawAmount
                barrel.m = targetMedium
                changed = true
            end
        end
    end
    return found, changed
end

function WaterpipesAdapter.setBunkerPumpForQa(gmd, condition, filterRemaining, burn)
    local pumps = type(gmd) == "table" and type(gmd.Pumps) == "table" and gmd.Pumps or {}
    local pump = pumps[coordsId(Constants.BUNKER_WATER_PUMP)]
    if type(pump) ~= "table" then return false end
    if condition ~= nil then pump.efficiency = Util.numberOr(condition, 1, 0, 1) * 100 end
    if filterRemaining ~= nil then
        pump.filter = Util.numberOr(filterRemaining, 1, 0, 1) * 100
        pump.BunkerCampaignStoredFilter = nil
        pump.BunkerCampaignBypass = false
    end
    if type(burn) == "boolean" then pump.burn = burn end
    return true
end

function WaterpipesAdapter.consumeTreatmentFilter(gmd, liters)
    local pumps = type(gmd) == "table" and type(gmd.Pumps) == "table" and gmd.Pumps or {}
    local pump = pumps[coordsId(Constants.BUNKER_WATER_PUMP)]
    if type(pump) ~= "table" or pump.active ~= true or pump.source ~= "TaintedWater"
        or pump.BunkerCampaignBypass == true then return false, 0 end
    local remaining = Util.numberOr(pump.filter, 0, 0, 100)
    liters = Util.numberOr(liters, 0, 0, BunkerCampaign.Constants.WATER.MAX_FLOW_PER_MINUTE)
    if remaining <= 0 or liters <= 0 then return false, 0 end
    local capacity = math.max(1, tonumber(Constants.BUNKER_WATER_FILTER_CAPACITY_LITERS) or 1000)
    local usedPercent = math.min(remaining, liters / capacity * 100)
    pump.filter = math.max(0, remaining - usedPercent)
    return usedPercent > 0, usedPercent / 100
end

function WaterpipesAdapter.sample(gmd)
    local result = {
        adapterOnline = type(gmd) == "table",
        physicallyAvailable = false,
        pumpPresent = false,
        pumpActive = false,
        pumpCondition = 0,
        status = "offline",
        filterRemaining = 0,
        stored = 0,
        capacity = 0,
        contamination = 0,
        flowPerMinute = 0,
        powerDemandKw = 0,
        source = "none",
        cleanStored = 0,
        taintedStored = 0,
        storageFull = false,
        burn = false,
    }
    if type(gmd) ~= "table" then return result end

    local pumps = type(gmd.Pumps) == "table" and gmd.Pumps or {}
    local pump = pumps[coordsId(Constants.BUNKER_WATER_PUMP)]
    if type(pump) ~= "table" then return result end

    result.physicallyAvailable = true
    result.pumpPresent = true
    result.pumpActive = pump.active == true
    result.burn = pump.burn == true
    result.pumpCondition = normalizePercent(pump.efficiency)
    result.filterRemaining = normalizePercent(pump.BunkerCampaignBypass == true
        and pump.BunkerCampaignStoredFilter or pump.filter)
    result.powerDemandKw = Constants.BUNKER_PUMP_POWER_DEMAND_KW

    if pump.source == "TaintedWater" then
        result.source = "underground_well"
    elseif pump.source == "Water" then
        result.source = "fresh_water"
    elseif pump.source == "Petrol" then
        result.source = "invalid_fuel"
    elseif type(pump.source) == "string" then
        result.source = pump.source
    end

    local taintedStored = 0
    local barrels = type(gmd.Barrels) == "table" and gmd.Barrels or {}
    for _, barrel in pairs(barrels) do
        if isInsideBunker(barrel) then
            local rawCapacity = Util.numberOr(barrel.wmax, 0, 0, BunkerCampaign.Constants.WATER.MAX_STORAGE)
            local rawStored = Util.numberOr(barrel.w, 0, 0, rawCapacity) / 100
            local _, physicalAmount, physicalCapacity, physicalMedium = physicalWater(barrel)
            local capacity = math.max(rawCapacity / 100, physicalCapacity)
            local stored = math.min(capacity, rawStored + physicalAmount)
            result.capacity = result.capacity + capacity
            result.stored = result.stored + stored
            local pendingTainted = barrel.m == "TaintedWater" and rawStored or 0
            local pendingClean = barrel.m == "Water" and rawStored or 0
            local physicalTainted = physicalMedium == "TaintedWater" and physicalAmount or 0
            local physicalClean = physicalMedium == "Water" and physicalAmount or 0
            local scale = rawStored + physicalAmount > capacity and capacity / (rawStored + physicalAmount) or 1
            local tainted = (pendingTainted + physicalTainted) * scale
            local clean = (pendingClean + physicalClean) * scale
            taintedStored = taintedStored + tainted
            result.taintedStored = result.taintedStored + tainted
            result.cleanStored = result.cleanStored + clean
        end
    end
    result.capacity = Util.clamp(result.capacity, 0, BunkerCampaign.Constants.WATER.MAX_STORAGE)
    result.stored = Util.clamp(result.stored, 0, result.capacity)
    result.storageFull = result.capacity > 0 and result.stored >= result.capacity - 0.0001

    if result.stored > 0 then result.contamination = taintedStored / result.stored end
    if result.pumpActive and pump.source == "TaintedWater"
        and (result.filterRemaining <= 0 or pump.BunkerCampaignBypass == true) then
        result.contamination = 1
    end

    local meters = type(gmd.Flowmeters) == "table" and gmd.Flowmeters or {}
    local meter = meters[coordsId(Constants.BUNKER_WATER_FLOWMETER)]
    if result.pumpActive and type(meter) == "table" then
        result.flowPerMinute = Util.numberOr(meter.f, 0, 0, BunkerCampaign.Constants.WATER.MAX_FLOW_PER_MINUTE) / 100
    end

    if pump.burn == true or result.pumpCondition <= 0 or result.source == "invalid_fuel" or result.source == "none" then
        result.status = "failed"
    elseif not result.pumpActive then
        result.status = "offline"
    elseif result.contamination > 0 then
        result.status = "contaminated"
    elseif result.pumpCondition < 0.5 or (pump.source == "TaintedWater" and result.filterRemaining < 0.2) then
        result.status = "degraded"
    else
        result.status = "operational"
    end
    return result
end

BunkerCampaignIntegration.WaterpipesAdapter = WaterpipesAdapter
return WaterpipesAdapter
