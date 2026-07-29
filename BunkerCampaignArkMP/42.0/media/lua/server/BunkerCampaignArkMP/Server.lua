if isClient() then return end

require "BWOAGMD"
require "BWOABuildTools"
require "BWOAPrepareTools"
require "BunkerCampaign/CampaignState"
require "BunkerCampaignArkMP/Constants"
require "BunkerCampaignArkMP/PowerGrid"

BunkerCampaignArkMP = BunkerCampaignArkMP or {}

local Constants = BunkerCampaignArkMP.Constants
local PowerGrid = BunkerCampaignArkMP.PowerGrid
local Server = { state = nil, missingSignature = nil, lightManifestSent = {} }

local function prepareState(data)
    if type(data) ~= "table" then error("Ark MP state must be a table") end
    local storedVersion = tonumber(data.version) or 0
    if storedVersion > Constants.STATE_VERSION then
        error("Ark MP state is newer than this mod")
    end
    data.version = Constants.STATE_VERSION
    data.status = type(data.status) == "string" and data.status or "waiting_for_chunks"
    if data.status == "building" then data.status = "waiting_for_chunks" end
    if type(data.builtRooms) ~= "table" then data.builtRooms = {} end
    if type(data.preparedRooms) ~= "table" then data.preparedRooms = {} end
    if type(data.errors) ~= "table" then data.errors = {} end
    if type(data.players) ~= "table" then data.players = {} end
    -- A version change is an explicit one-time retry after code migration.
    -- Failures on the current version remain latched until an admin retries.
    if storedVersion < Constants.STATE_VERSION
        and (data.status == "build_error" or data.status == "prepare_error") then
        data.status = "waiting_for_chunks"
    end
end

local function transmitState()
    if isServer() then ModData.transmit(Constants.STATE_KEY) end
end

local function missingProbes()
    local missing = {}
    local cell = getCell()
    if not cell then return { "cell" } end
    for _, probe in ipairs(Constants.BUILD_PROBES) do
        local square = cell:getGridSquare(probe.x, probe.y, probe.z)
        if not square or not square:getChunk() then
            missing[#missing + 1] = probe.name or (tostring(probe.x) .. "," .. tostring(probe.y) .. "," .. tostring(probe.z))
        end
    end
    return missing
end

local function chunksReady()
    local missing = missingProbes()
    local signature = table.concat(missing, ",")
    if signature ~= Server.missingSignature then
        Server.missingSignature = signature
        if #missing > 0 then
            print("[BunkerCampaignArkMP] waiting for map probes: " .. signature)
        else
            print("[BunkerCampaignArkMP] all map probes loaded")
        end
    end
    Server.state.missingProbes = missing
    return #missing == 0
end

local function recordError(roomName, phase, message)
    Server.state.errors[roomName .. ":" .. phase] = tostring(message)
    print("[BunkerCampaignArkMP] " .. phase .. " failed room=" .. roomName .. " error=" .. tostring(message))
end

local function runRoomPhase(roomName, phase, completed)
    if completed[roomName] then return true end
    local room = type(BWOARooms) == "table" and BWOARooms[roomName] or nil
    local fn = room and room[phase]
    if type(fn) ~= "function" then
        completed[roomName] = true
        return true
    end

    local ok, message = pcall(fn)
    if not ok then
        recordError(roomName, phase, message)
        return false
    end
    completed[roomName] = true
    Server.state.errors[roomName .. ":" .. phase] = nil
    transmitState()
    return true
end

function Server.repairWaterPump()
    if not getCell or type(WPIso) ~= "table" or type(WPIso.GetPump) ~= "function" then return false end
    local cell = getCell()
    if not cell then return false end
    local square = cell:getGridSquare(9950, 12616, -4)
    if not square or not square:getChunk() then return false end
    if WPIso.GetPump(square) then
        Server.waterPumpRepairError = nil
        return true
    end

    local ok, message = pcall(BWOABuildTools.WaterPump, 9950, 12616, -4)
    if not ok then
        local errorText = tostring(message)
        if Server.waterPumpRepairError ~= errorText then
            Server.waterPumpRepairError = errorText
            print("[BunkerCampaignArkMP] water pump repair failed error=" .. errorText)
        end
        return false
    end

    if WPIso.GetPump(square) then
        Server.waterPumpRepairError = nil
        print("[BunkerCampaignArkMP] restored missing bunker water pump at 9950,12616,-4")
        return true
    end
    return false
end

function Server.tryBuild()
    if not Server.state then return end
    if Server.state.status == "ready" then
        Server.repairWaterPump()
        -- Minute maintenance keeps bridge generators and water state healthy;
        -- the larger light scan is driven by power changes, initialization and
        -- player arrival instead of every in-game minute.
        PowerGrid.sync(false)
        return
    end
    if Server.state.status == "build_error" or Server.state.status == "prepare_error" then return end
    if not chunksReady() then
        Server.state.status = "waiting_for_chunks"
        return
    end

    Server.state.status = "building"
    transmitState()

    for _, roomName in ipairs(Constants.ROOMS) do
        if not runRoomPhase(roomName, "Build", Server.state.builtRooms) then
            Server.state.status = "build_error"
            transmitState()
            return
        end
    end

    Server.state.status = "preparing"
    transmitState()
    for _, roomName in ipairs(Constants.ROOMS) do
        if not runRoomPhase(roomName, "Prepare", Server.state.preparedRooms) then
            Server.state.status = "prepare_error"
            transmitState()
            return
        end
    end

    Server.state.status = "ready"
    Server.state.completedWorldAgeHours = getGameTime() and getGameTime():getWorldAgeHours() or 0
    transmitState()
    ModData.transmit(Constants.ARK_STATE_KEY)
    Server.repairWaterPump()
    PowerGrid.sync(true)
    Server.sanitizeLightUpdaters()
    print("[BunkerCampaignArkMP] bunker construction ready")
end

function Server.onLoadGridSquare(square)
    -- LoadGridsquare fires once for every streamed square.  Once construction
    -- is complete, running repairWaterPump() and PowerGrid.sync() from this
    -- event turns a long-distance teleport or a client join into thousands of
    -- full bunker scans.  Grid loading is only a construction wake-up signal;
    -- steady-state maintenance is handled by EveryOneMinute.
    if not Server.state or Server.state.status == "ready" then return end
    Server.tryBuild()
end

function Server.initializeRoomMetadata()
    -- Room Build() functions normally call Init(), but a completed save skips
    -- Build() on later server starts.  Recreate the coordinate manifests used
    -- by power/light control without touching any world objects.
    for _, roomName in ipairs(Constants.ROOMS) do
        local room = BWOARooms and BWOARooms[roomName] or nil
        if room and type(room.Init) == "function" then
            local ok, message = pcall(room.Init)
            if not ok then
                print("[BunkerCampaignArkMP] room metadata initialization failed room="
                    .. tostring(roomName) .. " error=" .. tostring(message))
            end
        end
    end
end

local function sendStatus(player)
    if player and isServer() then
        sendServerCommand(player, Constants.NETWORK_MODULE, "status", {
            version = Server.state.version,
            status = Server.state.status,
            errors = Server.state.errors,
        })
    end
end

local function sendLightingState(player)
    if not player or not isServer() then return end
    sendServerCommand(player, Constants.NETWORK_MODULE, "powerLighting", PowerGrid.getLightingState())
end

local function isMapSwitch(object)
    if not object or not instanceof(object, "IsoLightSwitch") then return false end
    local sprite = object:getSprite()
    local props = sprite and sprite:getProperties() or nil
    return props and props:has("CustomName") and props:get("CustomName") == "Switch"
end

local function insideLightScan(object)
    if not object then return false end
    local scan = Constants.LIGHT_SCAN
    local x, y, z = math.floor(object:getX()), math.floor(object:getY()), math.floor(object:getZ())
    if x < scan.x1 or x > scan.x2 or y < scan.y1 or y > scan.y2 then return false end
    for _, level in ipairs(scan.levels) do
        if z == level then return true end
    end
    return false
end

function Server.sanitizeLightUpdaters()
    local cell = getCell()
    local updaters = cell and cell.getStaticUpdaterObjectList and cell:getStaticUpdaterObjectList() or nil
    if not updaters then return end

    local orphaned, disabled = 0, 0
    for index = updaters:size() - 1, 0, -1 do
        local object = updaters:get(index)
        if instanceof(object, "IsoLightSwitch") and insideLightScan(object) then
            if object:getObjectIndex() < 0 then
                -- Old saves may contain switches removed from getObjects() by
                -- the original SP DarkenLight implementation.  removeFromWorld
                -- is required to also detach them from staticUpdaterObjectList.
                object:removeFromWorld()
                orphaned = orphaned + 1
            elseif object:getUseBattery() and object:getCanBeModified() then
                -- Existing valid decorative battery lights need no server tick.
                object:setCanBeModified(false)
                disabled = disabled + 1
            end
        end
    end
    if orphaned > 0 or disabled > 0 then
        print("[BunkerCampaignArkMP] light updater cleanup orphaned=" .. tostring(orphaned)
            .. " disabled=" .. tostring(disabled))
    end
end

local function sendLightManifest(player)
    if not player or not isServer() then return end
    local cell = getCell()
    local scan = Constants.LIGHT_SCAN
    local lights = {}
    local roleCounts = { main=0, emergency=0, decorative=0 }
    local emergencyCoordinates = {}

    for _, room in pairs(type(BWOARooms) == "table" and BWOARooms or {}) do
        if type(room) == "table" and type(room.els) == "table" then
            for _, coords in pairs(room.els) do
                emergencyCoordinates[tostring(coords.x) .. ":" .. tostring(coords.y) .. ":" .. tostring(coords.z)] = true
            end
        end
    end

    for _, z in ipairs(scan.levels) do
        for x = scan.x1, scan.x2 do
            for y = scan.y1, scan.y2 do
                local square = cell:getGridSquare(x, y, z)
                if square and square:getChunk() then
                    local occurrences = {}
                    local objects = square:getObjects()
                    for index = 0, objects:size() - 1 do
                        local object = objects:get(index)
                        if instanceof(object, "IsoLightSwitch") then
                            local sprite = object:getSprite()
                            local spriteName = sprite and sprite:getName() or nil
                            if spriteName then
                                occurrences[spriteName] = (occurrences[spriteName] or 0) + 1
                                local props = sprite:getProperties()
                                local coordinateKey = tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
                                local role = "decorative"
                                if object:getUseBattery() and emergencyCoordinates[coordinateKey] then
                                    role = "emergency"
                                elseif not object:getUseBattery() then
                                    role = "main"
                                end
                                roleCounts[role] = roleCounts[role] + 1
                                lights[#lights + 1] = {
                                    x=x, y=y, z=z,
                                    sprite=spriteName,
                                    occurrence=occurrences[spriteName],
                                    role=role,
                                    active=object:isActivated(),
                                    useBattery=object:getUseBattery(),
                                    hasBattery=object:getHasBattery(),
                                    lightR=tonumber(props and props:get("lightR")) or 255,
                                    lightG=tonumber(props and props:get("lightG")) or 240,
                                    lightB=tonumber(props and props:get("lightB")) or 180,
                                    radius=tonumber(props and props:get("LightRadius")) or 4,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    local phantoms = {}
    for _, point in ipairs(Constants.DARKENED_MAP_LIGHTS) do
        local square = cell:getGridSquare(point.x, point.y, point.z)
        local found = false
        if square then
            local objects = square:getObjects()
            for index = 0, objects:size() - 1 do
                if isMapSwitch(objects:get(index)) then found = true; break end
            end
        end
        if square and not found then phantoms[#phantoms + 1] = point end
    end

    sendServerCommand(player, Constants.NETWORK_MODULE, "lightManifest", {
        lights=lights,
        phantoms=phantoms,
        lighting=PowerGrid.getLightingState(),
    })
    print("[BunkerCampaignArkMP] light manifest sent player=" .. player:getUsername()
        .. " lights=" .. tostring(#lights) .. " main=" .. tostring(roleCounts.main)
        .. " emergency=" .. tostring(roleCounts.emergency)
        .. " decorative=" .. tostring(roleCounts.decorative)
        .. " phantoms=" .. tostring(#phantoms))
end

local function sendTeleport(player, target, confirmArrival)
    -- Use the native multiplayer teleport packet.  Calling teleportTo on both
    -- sides makes the following PlayerUpdate look like an illicit long-range
    -- move and may trigger AntiCheatPlayer.
    local nativeTeleport = false
    local ok, message = pcall(function()
        if GameServer and GameServer.sendTeleport then
            GameServer.sendTeleport(player, target.x, target.y, target.z)
            nativeTeleport = true
        else
            -- In B42.19 NetworkPlayerAI is exposed to Lua as opaque Java
            -- userdata.  Looking up resetSpeedLimiter/resetState emits a full
            -- Kahlua error even inside pcall.  The owning client receives the
            -- authorized target below, so the server-side position update is
            -- sufficient for this fallback.
            player:teleportTo(target.x, target.y, target.z)
        end
    end)
    if not ok then
        print("[BunkerCampaignArkMP] server-side teleport failed player=" .. player:getUsername()
            .. " error=" .. tostring(message))
    end

    sendServerCommand(player, Constants.NETWORK_MODULE, "teleportToBunker", {
        x = target.x,
        y = target.y,
        z = target.z,
        spawnVersion = Constants.SPAWN_VERSION,
        confirmArrival = confirmArrival == true,
        nativeTeleport = nativeTeleport,
    })
end

local function sendSpawn(player)
    sendTeleport(player, Constants.SPAWN, true)
end

local function playerAtBunker(player)
    if not player then return false end
    return math.abs(player:getX() - Constants.SPAWN.x) <= 12
        and math.abs(player:getY() - Constants.SPAWN.y) <= 12
        and math.abs(player:getZ() - Constants.SPAWN.z) < 0.1
end

function Server.onClientCommand(module, command, player, args)
    if module ~= Constants.NETWORK_MODULE or not player then return end
    if command == "joinReady" then
        Server.state.players[player:getUsername()] = true
        print("[BunkerCampaignArkMP] entry requested player=" .. player:getUsername()
            .. " from=" .. math.floor(player:getX()) .. "," .. math.floor(player:getY()) .. "," .. tostring(player:getZ()))
        sendSpawn(player)
        sendStatus(player)
        return
    end
    if command == "arrived" then
        if not playerAtBunker(player) then
            print("[BunkerCampaignArkMP] arrival not yet confirmed player=" .. player:getUsername()
                .. " at=" .. math.floor(player:getX()) .. "," .. math.floor(player:getY()) .. "," .. tostring(player:getZ()))
            sendSpawn(player)
            return
        end
        print("[BunkerCampaignArkMP] arrival confirmed player=" .. player:getUsername())
        Server.tryBuild()
        -- Reconcile all currently streamed fixtures once, then give this
        -- player the current authoritative state even when no global power
        -- transition occurred during their connection.
        PowerGrid.sync(true)
        sendLightingState(player)
        local username = player:getUsername()
        local manifestKey = username .. ":" .. tostring(player)
        if Server.state.status == "ready" and not Server.lightManifestSent[manifestKey] then
            sendLightManifest(player)
            Server.lightManifestSent[manifestKey] = true
        end
        sendStatus(player)
        return
    end
    if command == "requestStatus" then
        sendStatus(player)
        return
    end
    if command == "retryBuild" and player:isAccessLevel("admin") then
        print("[BunkerCampaignArkMP] construction retry requested player=" .. player:getUsername())
        Server.state.status = "waiting_for_chunks"
        transmitState()
        Server.tryBuild()
        sendStatus(player)
        return
    end
    if command == "inspectLevel" and player:isAccessLevel("admin") and type(args) == "table" then
        local target = Constants.INSPECTION_POINTS[args.level]
        if target then
            print("[BunkerCampaignArkMP] inspection teleport level=" .. tostring(args.level)
                .. " player=" .. player:getUsername())
            sendTeleport(player, target, false)
        end
        return
    end
    print("[BunkerCampaignArkMP] rejected unknown command=" .. tostring(command) .. " player=" .. player:getUsername())
end

function Server.initialize(isNewGame)
    InitBWOAModData(isNewGame)
    Server.state = ModData.getOrCreate(Constants.STATE_KEY)
    prepareState(Server.state)
    Server.initializeRoomMetadata()
    BunkerCampaign.CampaignState.addPowerListener(PowerGrid.sync)
    transmitState()
    Server.tryBuild()
    Server.sanitizeLightUpdaters()
    if Server.state.status == "ready" then PowerGrid.sync(true) end
    print("[BunkerCampaignArkMP] server state ready status=" .. Server.state.status)
end

function Server.onServerStarted()
    PowerGrid.setNetworkReady(true)
    -- Broadcast the current logical state now that GameServer.udpEngine exists;
    -- no physical light scan is needed here.
    PowerGrid.sync(false)
end

Events.OnInitGlobalModData.Add(Server.initialize)
Events.OnServerStarted.Add(Server.onServerStarted)
Events.EveryOneMinute.Add(Server.tryBuild)
Events.OnClientCommand.Add(Server.onClientCommand)
Events.LoadGridsquare.Add(Server.onLoadGridSquare)

BunkerCampaignArkMP.Server = Server
return Server
