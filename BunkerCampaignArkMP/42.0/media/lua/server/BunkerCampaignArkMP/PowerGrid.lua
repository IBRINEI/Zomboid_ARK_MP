if isClient() then return end

require "BunkerCampaignArkMP/Constants"

BunkerCampaignArkMP = BunkerCampaignArkMP or {}

local Constants = BunkerCampaignArkMP.Constants
local PowerGrid = {
    lastGridOnline = nil,
    lastMainLights = nil,
    lastEmergencyLights = nil,
    lastBroadcastMainLights = nil,
    lastBroadcastEmergencyLights = nil,
    networkReady = false,
}

local EMERGENCY_SPRITE_BY_DIRECTION = {
    N = "location_entertainment_theatre_01_138",
    W = "location_entertainment_theatre_01_136",
    S = "location_entertainment_theatre_01_142",
    E = "location_entertainment_theatre_01_140",
    XN = "lighting_indoor_01_25",
    XW = "lighting_indoor_01_24",
}

local function lightKey(x, y, z, spriteName)
    return tostring(math.floor(tonumber(x) or 0)) .. ":"
        .. tostring(math.floor(tonumber(y) or 0)) .. ":"
        .. tostring(math.floor(tonumber(z) or 0)) .. ":" .. tostring(spriteName or "")
end

function PowerGrid.buildExpectedEmergencyLights()
    local expected = {}
    for _, room in pairs(type(BWOARooms) == "table" and BWOARooms or {}) do
        if type(room) == "table" and type(room.els) == "table" then
            for _, coords in pairs(room.els) do
                local spriteName = EMERGENCY_SPRITE_BY_DIRECTION[coords.dir]
                if spriteName then
                    expected[lightKey(coords.x, coords.y, coords.z, spriteName)] = true
                end
            end
        end
    end
    return expected
end

function PowerGrid.classifyLight(object, x, y, z, expected)
    if not object or not instanceof(object, "IsoLightSwitch") then return nil end
    local sprite = object:getSprite()
    local spriteName = sprite and sprite:getName() or nil
    expected = expected or PowerGrid.buildExpectedEmergencyLights()
    if spriteName and expected[lightKey(x, y, z, spriteName)] then return "emergency" end
    if not object:getUseBattery() then return "main" end
    return "decorative"
end

function PowerGrid.repairEmergencyLight(object)
    if not object then return end
    if object.setCanBeModified then object:setCanBeModified(false) end
    if object.setPower then object:setPower(1000) end
    if object.setHasBattery then object:setHasBattery(true) end
    if object.setUseBatteryDirect then object:setUseBatteryDirect(true) end
end

local function createBridgeGenerator(square)
    local item = BanditCompatibility.InstanceItem("Bandits.Generator_Silent")
    if not item then item = BanditCompatibility.InstanceItem("Base.Generator_Old") end
    if not item then return nil end

    local generator = IsoGenerator.new(item, getCell(), square)
    if not generator then return nil end
    local md = generator:getModData()
    md.BunkerCampaignGridBridge = true
    generator:setCondition(100)
    generator:setFuel(100)
    generator:setConnected(true)
    local properties = generator:getProperties()
    if properties then properties:set("GeneratorSound", "silenced") end
    generator:transmitCompleteItemToClients()
    square:setSquareChanged()
    return generator
end

local function syncBridgeGenerator(coords, active)
    local cell = getCell()
    local square = cell and cell:getOrCreateGridSquare(coords.x, coords.y, coords.z) or nil
    if not square or not square:getChunk() then return false end
    local generator = square:getGenerator()
    if not generator then generator = createBridgeGenerator(square) end
    if not generator then return false end

    generator:getModData().BunkerCampaignGridBridge = true
    generator:setCondition(100)
    generator:setFuel(100)
    generator:setConnected(true)
    local changed = generator:isActivated() ~= active
    if changed then
        generator:setActivated(active)
        generator:sync()
    end
    -- The logical generators in CampaignState own fuel and wear.  These six
    -- silent objects exist only to make vanilla square:haveElectricity() and
    -- third-party consumers such as Waterpipes see the bunker grid.  Their
    -- native fuel is pinned on every synchronization pass.
    return true
end

local function eachLight(role, callback)
    local cell = getCell()
    if not cell then return 0 end
    local found = 0
    local scan = Constants.LIGHT_SCAN
    local expected = PowerGrid.buildExpectedEmergencyLights()
    for _, z in ipairs(scan.levels) do
        for x = scan.x1, scan.x2 do
            for y = scan.y1, scan.y2 do
                local square = cell:getGridSquare(x, y, z)
                if square and square:getChunk() then
                    local objects = square:getObjects()
                    for index = 0, objects:size() - 1 do
                        local object = objects:get(index)
                        if object:getObjectIndex() >= 0
                            and PowerGrid.classifyLight(object, x, y, z, expected) == role then
                            if role == "emergency" then PowerGrid.repairEmergencyLight(object) end
                            found = found + 1
                            callback(object)
                        end
                    end
                end
            end
        end
    end
    return found
end

local function eachMainLight(callback)
    return eachLight("main", callback)
end

local function eachEmergencyLight(callback)
    return eachLight("emergency", callback)
end

local function setLightActive(object, active)
    if object:isActivated() == active then return false end
    -- setActive already updates the physical light and performs one network
    -- synchronization.  The force flag avoids canSwitchLight rejecting the
    -- artificial permanent-battery fixtures.
    object:setActive(active, false, true)
    return object:isActivated() == active
end

local function syncLights(mainActive, emergencyActive)
    local changed, mainChanged, emergencyChanged = 0, 0, 0
    -- B42 may stream saved IsoLightSwitch objects after an earlier power-state
    -- transition.  Always reconcile currently loaded fixtures when sync() is
    -- called; setLightActive remains idempotent and only transmits real changes.
    local mainFound = eachMainLight(function(object)
        if setLightActive(object, mainActive) then
            changed = changed + 1
            mainChanged = mainChanged + 1
        end
    end)
    if mainFound > 0 then PowerGrid.lastMainLights = mainActive end

    local emergencyFound = eachEmergencyLight(function(object)
        if setLightActive(object, emergencyActive) then
            changed = changed + 1
            emergencyChanged = emergencyChanged + 1
        end
    end)
    if emergencyFound > 0 then PowerGrid.lastEmergencyLights = emergencyActive end
    if changed > 0 then
        print("[BunkerCampaignArkMP] power lighting synchronized changed=" .. tostring(changed)
            .. " main=" .. tostring(mainChanged) .. " emergency=" .. tostring(emergencyChanged))
    end
end

local function broadcastLightingState(mainActive, emergencyActive)
    if PowerGrid.lastBroadcastMainLights == mainActive
        and PowerGrid.lastBroadcastEmergencyLights == emergencyActive then return end
    PowerGrid.lastBroadcastMainLights = mainActive
    PowerGrid.lastBroadcastEmergencyLights = emergencyActive
    -- isServer() is already true while GlobalModData is initializing, before
    -- GameServer.udpEngine exists.  Broadcasting in that window throws an NPE.
    if isServer() and PowerGrid.networkReady then
        sendServerCommand(Constants.NETWORK_MODULE, "powerLighting", {
            mainActive=mainActive,
            emergencyActive=emergencyActive,
        })
    end
end

function PowerGrid.setNetworkReady(ready)
    PowerGrid.networkReady = ready == true
    if PowerGrid.networkReady then
        -- Force one current-state broadcast after the transport has started.
        PowerGrid.lastBroadcastMainLights = nil
        PowerGrid.lastBroadcastEmergencyLights = nil
    end
end

function PowerGrid.getLightingState()
    return {
        mainActive=PowerGrid.lastBroadcastMainLights == true,
        emergencyActive=PowerGrid.lastBroadcastEmergencyLights == true,
    }
end

function PowerGrid.sync(reconcileLights)
    local campaignState = BunkerCampaign and BunkerCampaign.CampaignState and BunkerCampaign.CampaignState.get()
    local power = campaignState and campaignState.bunker and campaignState.bunker.modules and campaignState.bunker.modules.power
    if not power then return false end

    local ready = true
    for _, coords in ipairs(Constants.GRID_GENERATORS) do
        if not syncBridgeGenerator(coords, power.gridOnline == true) then ready = false end
    end

    local consumers = power.consumers or {}
    local mainActive = consumers.main_lighting and consumers.main_lighting.allocated == true
    local emergencyActive = power.emergencyMode == true
        and consumers.emergency_lighting and consumers.emergency_lighting.allocated == true
    local lightingChanged = PowerGrid.lastBroadcastMainLights ~= (mainActive == true)
        or PowerGrid.lastBroadcastEmergencyLights ~= (emergencyActive == true)
    -- nil means a normal power-listener update: scan only on a real lighting
    -- transition.  true is used for startup/player-arrival reconciliation.
    if reconcileLights == true or (reconcileLights == nil and lightingChanged) then
        syncLights(mainActive == true, emergencyActive == true)
    end
    broadcastLightingState(mainActive == true, emergencyActive == true)

    if PowerGrid.lastGridOnline ~= power.gridOnline then
        PowerGrid.lastGridOnline = power.gridOnline
        print("[BunkerCampaignArkMP] physical grid " .. (power.gridOnline and "online" or "offline"))
    end
    return ready
end

BunkerCampaignArkMP.PowerGrid = PowerGrid
return PowerGrid
