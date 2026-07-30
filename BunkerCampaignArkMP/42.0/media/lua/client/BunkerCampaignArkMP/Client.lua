require "BWOAGMD"
require "BunkerCampaignArkMP/Constants"

BunkerCampaignArkMP = BunkerCampaignArkMP or {}

local Constants = BunkerCampaignArkMP.Constants
local Client = {
    status = nil,
    awaitingArrival = false,
    arrivalTicks = 0,
    joinTicks = 0,
    joinSent = false,
    teleportArgs = nil,
    teleportAttempts = 0,
    lightManifest = nil,
    lightManifestTicks = 0,
    lightManifestDirty = false,
    lightingState = nil,
}

local function send(command, args)
    local player = getSpecificPlayer(0)
    if isClient() and player then sendClientCommand(player, Constants.NETWORK_MODULE, command, args or {}) end
end

local function onCreatePlayer(playerIndex, player)
    if not player then return end
    ModData.request(Constants.ARK_STATE_KEY)
    Client.joinTicks = 0
    Client.joinSent = false
    Client.awaitingArrival = false
    Client.teleportArgs = nil
    Client.teleportAttempts = 0
end

local function trackServerTeleport(player, args)
    if not player or type(args) ~= "table" then return end
    if type(args.x) ~= "number" or type(args.y) ~= "number" or type(args.z) ~= "number" then return end

    -- GameServer.sendTeleport moves the client through the engine's Teleport
    -- packet.  Some server Lua environments do not expose GameServer itself;
    -- in that case the server prepositions and resets its network player, then
    -- explicitly asks this owning client to apply the same coordinates once.
    if args.nativeTeleport ~= true then
        player:teleportTo(args.x, args.y, args.z)
    end

    Client.teleportArgs = { x=args.x, y=args.y, z=args.z }
    Client.teleportAttempts = Client.teleportAttempts + 1
    Client.awaitingArrival = args.confirmArrival ~= false
    Client.arrivalTicks = 0
    print("[BunkerCampaignArkMP] server teleport tracked attempt=" .. tostring(Client.teleportAttempts)
        .. " target=" .. tostring(args.x) .. "," .. tostring(args.y) .. "," .. tostring(args.z))
end

local function onServerCommand(module, command, args)
    if module ~= Constants.NETWORK_MODULE then return end
    if command == "teleportToBunker" then
        trackServerTeleport(getSpecificPlayer(0), args)
    elseif command == "status" and type(args) == "table" then
        Client.status = args
    elseif command == "lightManifest" and type(args) == "table" then
        Client.lightManifest = args
        Client.lightingState = type(args.lighting) == "table" and args.lighting or Client.lightingState
        Client.lightManifestTicks = 0
        Client.lightManifestDirty = true
    elseif command == "powerLighting" and type(args) == "table" then
        Client.lightingState = {
            mainActive=args.mainActive == true,
            emergencyActive=args.emergencyActive == true,
        }
        Client.lightManifestTicks = 4
        Client.lightManifestDirty = Client.lightManifest ~= nil
    end
end

local function isMapSwitch(object)
    if not object or not instanceof(object, "IsoLightSwitch") then return false end
    local sprite = object:getSprite()
    local props = sprite and sprite:getProperties() or nil
    return props and props:has("CustomName") and props:get("CustomName") == "Switch"
end

local function removePhantomMapLight(point)
    local square = getCell():getGridSquare(point.x, point.y, point.z)
    -- A later LoadGridsquare event will schedule another reconciliation.
    if not square or not square:getChunk() then return true end
    local objects = square:getObjects()
    for index = objects:size() - 1, 0, -1 do
        local object = objects:get(index)
        if isMapSwitch(object) then square:RemoveTileObject(object) end
    end
    square:setSquareChanged()
    return true
end

local function desiredLightState(entry)
    local state = Client.lightingState
    if type(state) ~= "table" then return entry.active == true end
    if entry.role == "main" then return state.mainActive == true end
    if entry.role == "emergency" then return state.emergencyActive == true end
    return entry.active == true
end

local function setClientLightActive(light, active)
    -- switchLight may need to rebuild a local light source even when the
    -- serialized activated flag already matches, so always apply both calls.
    -- setActive(..., false, ...) sends SyncIsoObject back to the server.  That
    -- allowed one client with stale state to overwrite authoritative lighting
    -- every game minute.  Update only this client's field/light source; the
    -- server remains the sole network writer.
    light:setActivated(active)
    light:switchLight(active)
end

local function reconcileLight(entry)
    local square = getCell():getGridSquare(entry.x, entry.y, entry.z)
    -- Do not poll every unloaded manifest entry indefinitely.  Loading a
    -- bunker square marks the manifest dirty again below.
    if not square or not square:getChunk() then return true, 0 end
    local objects = square:getObjects()
    local count = 0
    local desiredActive = desiredLightState(entry)
    for index = 0, objects:size() - 1 do
        local object = objects:get(index)
        local sprite = object and object:getSprite() or nil
        if instanceof(object, "IsoLightSwitch") and sprite and sprite:getName() == entry.sprite then
            count = count + 1
            setClientLightActive(object, desiredActive)
        end
    end
    if count >= (tonumber(entry.occurrence) or 1) then return true, 0 end

    local sprite = getSprite(entry.sprite)
    local props = sprite:getProperties()
    props:set("lightR", tostring(entry.lightR or 255))
    props:set("lightG", tostring(entry.lightG or 240))
    props:set("lightB", tostring(entry.lightB or 180))
    props:set("LightRadius", tostring(entry.radius or 4))
    if props:has(IsoPropertyType.STREETLIGHT) then props:unset("streetlight") end

    local light = IsoLightSwitch.new(getCell(), square, sprite, square:getRoomID())
    if entry.useBattery then
        light:setCanBeModified(false)
        light:setPower(1000)
        light:setHasBattery(entry.hasBattery == true)
        light:setUseBatteryDirect(true)
    else
        light:setUseBattery(false)
    end
    light:addLightSourceFromSprite()
    light:setPrimaryR((tonumber(entry.lightR) or 255) / 255)
    light:setPrimaryG((tonumber(entry.lightG) or 240) / 255)
    light:setPrimaryB((tonumber(entry.lightB) or 180) / 255)
    square:AddSpecialObject(light)
    setClientLightActive(light, desiredActive)
    square:setSquareChanged()
    return true, 1
end

local function reconcileLightManifest()
    local manifest = Client.lightManifest
    if type(manifest) ~= "table" or not Client.lightManifestDirty then return end
    Client.lightManifestTicks = Client.lightManifestTicks + 1
    if Client.lightManifestTicks < 5 then return end
    Client.lightManifestTicks = 0

    local ready = true
    local added = 0
    for _, point in ipairs(type(manifest.phantoms) == "table" and manifest.phantoms or {}) do
        if not removePhantomMapLight(point) then ready = false end
    end
    for _, entry in ipairs(type(manifest.lights) == "table" and manifest.lights or {}) do
        local entryReady, entryAdded = reconcileLight(entry)
        if not entryReady then ready = false end
        added = added + entryAdded
    end
    if ready then
        print("[BunkerCampaignArkMP] light reconciliation complete added=" .. tostring(added))
        Client.lightManifestDirty = false
    end
end

local function onLoadGridSquare(square)
    if not square or not Client.lightManifest then return end
    local scan = Constants.LIGHT_SCAN
    local x, y, z = square:getX(), square:getY(), square:getZ()
    if x < scan.x1 or x > scan.x2 or y < scan.y1 or y > scan.y2 then return end
    for _, level in ipairs(scan.levels) do
        if z == level then
            Client.lightManifestDirty = true
            Client.lightManifestTicks = 0
            return
        end
    end
end

local function onPlayerUpdate(player)
    if not player or player:getPlayerNum() ~= 0 then return end
    reconcileLightManifest()

    if not Client.joinSent then
        Client.joinTicks = Client.joinTicks + 1
        if Client.joinTicks >= 30 and player:getCurrentSquare() then
            Client.joinSent = true
            sendClientCommand(player, Constants.NETWORK_MODULE, "joinReady", {})
        end
        return
    end

    if not Client.awaitingArrival then return end
    Client.arrivalTicks = Client.arrivalTicks + 1
    local square = player:getCurrentSquare()
    local target = Client.teleportArgs
    local atTarget = target
        and math.abs(player:getX() - target.x) <= 2
        and math.abs(player:getY() - target.y) <= 2
        and math.abs(player:getZ() - target.z) < 0.1
    if square and atTarget then
        Client.awaitingArrival = false
        sendClientCommand(player, Constants.NETWORK_MODULE, "arrived", {
            x=player:getX(), y=player:getY(), z=player:getZ(),
        })
    elseif Client.arrivalTicks >= 300 and Client.teleportAttempts < 4 then
        Client.arrivalTicks = 0
        sendClientCommand(player, Constants.NETWORK_MODULE, "joinReady", {})
    elseif Client.arrivalTicks > 1200 then
        Client.awaitingArrival = false
        print("[BunkerCampaignArkMP] bunker arrival timed out at="
            .. tostring(player:getX()) .. "," .. tostring(player:getY()) .. "," .. tostring(player:getZ()))
    end
end

local function retryEntry(player)
    if not player then return end
    Client.joinSent = true
    Client.awaitingArrival = false
    Client.arrivalTicks = 0
    Client.teleportArgs = nil
    Client.teleportAttempts = 0
    sendClientCommand(player, Constants.NETWORK_MODULE, "enterBunker", {})
end

local function addContextOptions(playerNum, context, worldObjects, test)
    if test and ISWorldObjectContextMenu and ISWorldObjectContextMenu.Test then return true end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    context:addOption("Bunker Campaign: Enter bunker", player, retryEntry)

    if isAdmin() or getAccessLevel() == "admin" then
        context:addOption("Bunker Campaign: Retry bunker construction", player, function(p)
            sendClientCommand(p, Constants.NETWORK_MODULE, "retryBuild", {})
        end)
        context:addOption("Bunker Campaign: Inspect service level (-5)", player, function(p)
            sendClientCommand(p, Constants.NETWORK_MODULE, "inspectLevel", { level="service" })
        end)
        context:addOption("Bunker Campaign: Inspect deep level (-7)", player, function(p)
            sendClientCommand(p, Constants.NETWORK_MODULE, "inspectLevel", { level="deep" })
        end)
    end
end

Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnServerCommand.Add(onServerCommand)
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.LoadGridsquare.Add(onLoadGridSquare)
Events.OnFillWorldObjectContextMenu.Add(addContextOptions)

BunkerCampaignArkMP.Client = Client
return Client
