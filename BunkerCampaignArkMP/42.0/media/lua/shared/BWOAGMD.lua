require "BunkerCampaignArkMP/Constants"

BWOAGlobalData = BWOAGlobalData or {}

local Constants = BunkerCampaignArkMP.Constants

local function ensureTable(parent, key)
    if type(parent[key]) ~= "table" then parent[key] = {} end
    return parent[key]
end

local function ensureState(data)
    if type(data) ~= "table" then data = {} end

    data.salvation = tonumber(data.salvation) or 1
    local noah = ensureTable(data, "noah")
    if type(noah.on) ~= "boolean" then noah.on = true end
    noah.state = type(noah.state) == "string" and noah.state or "operational"

    local climate = ensureTable(data, "climate")
    if type(climate.radiation) ~= "boolean" then climate.radiation = true end
    data.research = tonumber(data.research) or 0

    local generators = ensureTable(data, "generators")
    if type(generators.main) ~= "table" then
        generators.main = { x=9947, y=12621, z=-4, fuel=87, condition=81, coolant=72, lubricant=83, powerUsing=0, active=true }
    end
    if type(generators.backup) ~= "table" then
        generators.backup = { x=9947, y=12616, z=-4, fuel=50, condition=90, coolant=90, lubricant=90, powerUsing=0, active=false }
    end

    local ventilation = ensureTable(data, "ventilation")
    if type(ventilation.active) ~= "boolean" then ventilation.active = true end
    ventilation.co2 = tonumber(ventilation.co2) or 750
    ventilation.filter = tonumber(ventilation.filter) or 88
    if type(ventilation.heating) ~= "boolean" then ventilation.heating = true end
    if type(ventilation.open) ~= "boolean" then ventilation.open = true end
    ventilation.tempTarget = tonumber(ventilation.tempTarget) or 21
    ventilation.temp = tonumber(ventilation.temp) or 21

    if type(data.airintakes) ~= "table" or #data.airintakes == 0 then
        data.airintakes = {
            { x=9940, y=12633, z=0, broken=true },
            { x=9940, y=12634, z=0, broken=false },
            { x=9941, y=12633, z=0, broken=false },
            { x=9941, y=12634, z=0, broken=false },
        }
    end

    if type(data.waterpump) ~= "table" then data.waterpump = { x=9946, y=12618, z=-4, active=true } end
    if type(data.decontaminator) ~= "table" then data.decontaminator = { x=9948, y=12622, z=-5, concentration=85 } end
    if type(data.alerting) ~= "table" then
        data.alerting = { generatorFuelAlert=10, generatorConditionAlert=10, radiationAlert=10, co2Alert=10, waterPumpConditionAlert=10 }
    end

    -- These collections are retained for data compatibility only.  The MP fork
    -- deliberately does not load the single-player NPC/story handlers.
    ensureTable(data, "hatches")
    ensureTable(data, "dialogues")
    ensureTable(data, "missions")
    ensureTable(data, "placeEvents")
    ensureTable(data, "itemMemoryRegain")
    ensureTable(data, "permanentNPC")
    ensureTable(data, "arkNetwork")
    local nightmares = ensureTable(data, "nightmares")
    if type(nightmares.active) ~= "boolean" then nightmares.active = false end
    ensureTable(nightmares, "doneList")

    return data
end

function InitBWOAModData(isNewGame)
    if isClient() then
        BWOAGlobalData = ensureState(BWOAGlobalData)
        ModData.request(Constants.ARK_STATE_KEY)
        return
    end

    BWOAGlobalData = ensureState(ModData.getOrCreate(Constants.ARK_STATE_KEY))
    if isServer() then ModData.transmit(Constants.ARK_STATE_KEY) end
end

function LoadBWOAModData(key, globalData)
    if key ~= Constants.ARK_STATE_KEY then return end
    BWOAGlobalData = ensureState(globalData)
end

function GetBWOAModData()
    BWOAGlobalData = ensureState(BWOAGlobalData)
    return BWOAGlobalData
end

function TransmitBWOAModData()
    if isServer() then ModData.transmit(Constants.ARK_STATE_KEY) end
end

Events.OnInitGlobalModData.Add(InitBWOAModData)
Events.OnReceiveGlobalModData.Add(LoadBWOAModData)

BunkerCampaignArkMP.ensureArkState = ensureState
return BunkerCampaignArkMP
