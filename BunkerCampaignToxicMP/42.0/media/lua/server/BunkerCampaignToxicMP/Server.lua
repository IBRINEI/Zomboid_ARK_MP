if isClient() then return end

require "BunkerCampaignToxicMP/Constants"
require "BunkerCampaignToxicMP/ContaminationModel"

BunkerCampaignToxicMP = BunkerCampaignToxicMP or {}

local Constants = BunkerCampaignToxicMP.Constants
local ContaminationModel = BunkerCampaignToxicMP.ContaminationModel
local Server = {
    state = nil,
    zones = {},
    lastTickMs = 0,
    statusAccumulator = 0,
}

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function sanitizeZones(raw)
    local zones = {}
    if type(raw) ~= "table" then return zones end
    for name, zone in pairs(raw) do
        if #zones >= Constants.MAX_ZONES then break end
        if type(zone) == "table" then
            local x1, y1 = tonumber(zone.startX), tonumber(zone.startY)
            local x2, y2 = tonumber(zone.endX), tonumber(zone.endY)
            if finite(x1) and finite(y1) and finite(x2) and finite(y2)
                and math.abs(x2 - x1) <= Constants.MAX_ZONE_SPAN
                and math.abs(y2 - y1) <= Constants.MAX_ZONE_SPAN then
                zones[#zones + 1] = {
                    name=tostring(name),
                    x1=math.min(x1, x2), y1=math.min(y1, y2),
                    x2=math.max(x1, x2), y2=math.max(y1, y2),
                }
            end
        end
    end
    return zones
end

local function refreshZones()
    Server.zones = sanitizeZones(ModData.getOrCreate(Constants.ZONES_KEY))
end

local function zoneAt(x, y)
    for _, zone in ipairs(Server.zones) do
        if x >= zone.x1 and x <= zone.x2 and y >= zone.y1 and y <= zone.y2 then return zone end
    end
    return nil
end

local function containsPattern(value, patterns)
    value = string.lower(value or "")
    for _, pattern in ipairs(patterns) do
        if string.find(value, pattern, 1, true) then return true end
    end
    return false
end

local function itemCharge(item)
    local md = item:getModData()
    local charge = tonumber(md.percent)
    if charge == nil then charge = 1; md.percent = charge end
    return math.max(0, math.min(1, charge))
end

local function classifyProtection(player)
    local godMode = player:isGodMod()
    local worn = player:getWornItems()
    local cloth = false
    local gasMask, gasCharge = nil, nil
    for index = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(index)
        if item then
            local itemType = item:getType()
            if Constants.PROTECTIVE_MASKS[itemType] or containsPattern(itemType, Constants.GAS_MASK_PATTERNS) then
                local charge = itemCharge(item)
                if not gasMask then gasMask, gasCharge = item, charge end
            elseif containsPattern(itemType, Constants.CLOTH_MASK_PATTERNS) then
                cloth = true
            end
        end
    end
    if gasMask and gasCharge > 0 then return 1, gasMask, gasCharge, cloth end
    if godMode then return 1, gasMask, gasCharge, cloth end
    return cloth and (1 / 3) or 0, gasMask, gasCharge, cloth
end

local function multiplier(name, fallback)
    local vars = SandboxVars and SandboxVars.ToxicZonesStalker
    local value = vars and tonumber(vars[name])
    return value and math.max(0.01, value) or fallback
end

local function syncItem(player, item)
    if not item then return end
    if type(syncItemModData) == "function" then
        pcall(syncItemModData, player, item)
    end
    if type(syncItemFields) == "function" then
        pcall(syncItemFields, player, item)
    end
    if item.syncItemFields then
        pcall(item.syncItemFields, item)
    end
    if type(sendItemStats) == "function" then
        pcall(sendItemStats, item)
    end
end

local function itemContamination(item)
    if not item or not item.getModData then return 0 end
    return ContaminationModel.clamp(item:getModData()[Constants.CONTAMINATION_MODDATA_KEY])
end

local function setItemContamination(player, item, value, forceSync)
    if not item or not item.getModData then return false end
    value = ContaminationModel.clamp(value)
    local md = item:getModData()
    local previous = ContaminationModel.clamp(md[Constants.CONTAMINATION_MODDATA_KEY])
    if math.abs(previous - value) < 0.0001 then return false end
    md[Constants.CONTAMINATION_MODDATA_KEY] = value

    local lastSynced = tonumber(md.BunkerCampaignLastSyncedContamination) or 0
    if forceSync or math.abs(value - lastSynced) >= Constants.SURFACE_ITEM_SYNC_DELTA then
        md.BunkerCampaignLastSyncedContamination = value
        syncItem(player, item)
    end
    return true
end

local function collectWornItems(player)
    local result = {}
    local worn = player and player.getWornItems and player:getWornItems() or nil
    if not worn then return result end
    for index = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(index)
        if item then result[#result + 1] = item end
    end
    return result
end

local function collectCarriedItems(player, limit)
    local result = {}
    local seen = {}
    limit = math.max(1, tonumber(limit) or Constants.MAX_CARRIED_ITEMS_PER_SCAN)
    local root = player and player.getInventory and player:getInventory() or nil
    if not root or not root.getItems then return result end

    local containers = { root }
    local containerIndex = 1
    while containerIndex <= #containers and #result < limit do
        local container = containers[containerIndex]
        containerIndex = containerIndex + 1
        local items = container and container:getItems() or nil
        if items then
            for index = 0, items:size() - 1 do
                if #result >= limit then break end
                local item = items:get(index)
                if item and not seen[item] then
                    seen[item] = true
                    result[#result + 1] = item
                    local isContainer = type(instanceof) == "function"
                        and instanceof(item, "InventoryContainer")
                        or (type(instanceof) ~= "function" and item.getInventory ~= nil)
                    if isContainer and item:getModData().BunkerCampaignSealed ~= true then
                        local nested = item:getInventory()
                        if nested then containers[#containers + 1] = nested end
                    end
                end
            end
        end
    end
    return result
end

local function updateSurfaceContamination(player, record, zone, elapsed, scanCarried, carriedElapsed)
    local surface = ContaminationModel.clamp(record.surfaceContamination)
    local wornItems = collectWornItems(player)
    local gearMaximum = 0

    if zone then
        surface = ContaminationModel.deposit(surface, Constants.SURFACE_BODY_DEPOSIT_PER_SECOND, elapsed)
        for _, item in ipairs(wornItems) do
            local nextValue = ContaminationModel.deposit(
                itemContamination(item),
                Constants.SURFACE_GEAR_DEPOSIT_PER_SECOND,
                elapsed
            )
            setItemContamination(player, item, nextValue, false)
            gearMaximum = math.max(gearMaximum, nextValue)
        end
        if scanCarried then
            local wornSet = {}
            for _, item in ipairs(wornItems) do wornSet[item] = true end
            for _, item in ipairs(collectCarriedItems(player, Constants.MAX_CARRIED_ITEMS_PER_SCAN)) do
                if not wornSet[item] then
                    local nextValue = ContaminationModel.deposit(
                        itemContamination(item),
                        Constants.SURFACE_PACKED_ITEM_DEPOSIT_PER_SECOND,
                        carriedElapsed or elapsed
                    )
                    setItemContamination(player, item, nextValue, false)
                    gearMaximum = math.max(gearMaximum, nextValue)
                end
            end
        end
    else
        for _, item in ipairs(wornItems) do
            gearMaximum = math.max(gearMaximum, itemContamination(item))
        end
        if scanCarried then
            for _, item in ipairs(collectCarriedItems(player, Constants.MAX_CARRIED_ITEMS_PER_SCAN)) do
                gearMaximum = math.max(gearMaximum, itemContamination(item))
            end
        end
        surface = ContaminationModel.contact(
            surface,
            gearMaximum,
            Constants.SURFACE_CONTACT_FRACTION_PER_SECOND * elapsed
        )
    end

    if not scanCarried then
        gearMaximum = math.max(gearMaximum, ContaminationModel.clamp(record.gearContamination))
    end

    record.surfaceContamination = surface
    record.gearContamination = gearMaximum
end

local function setVisibleFilterCondition(item, remaining)
    if not item or not item.getConditionMax or not item.setCondition then return false end
    local maximum = tonumber(item:getConditionMax()) or 0
    if maximum > 0 then
        local condition = remaining <= 0 and 0 or math.max(1, math.floor(maximum * remaining))
        if item:getCondition() ~= condition then
            item:setCondition(condition)
            return true
        end
    end
    return false
end

local function filterIdentity(item)
    if not item or not item.getID then return nil, nil end
    local ok, id = pcall(item.getID, item)
    if not ok or id == nil then return nil, nil end
    return id, tostring(id)
end

local function kill(player)
    player:setHealth(0)
    if player.Kill then pcall(player.Kill, player, nil) end
end

local function updatePlayer(player, elapsed, scanCarried, carriedElapsed)
    if not player then return nil end
    local username = player:getUsername()
    local record = Server.state.players[username]
    if type(record) ~= "table" then record = { exposure=0, surfaceContamination=0 }; Server.state.players[username] = record end
    if player:isDead() then
        record.awaitingRespawn = true
        return nil
    end
    if record.awaitingRespawn then
        record = { exposure=0, surfaceContamination=0 }
        Server.state.players[username] = record
        print("[BunkerCampaignToxicMP] exposure reset for respawn player=" .. username)
    end

    local zone = zoneAt(player:getX(), player:getY())
    local level, mask, observedCharge, hasCloth = classifyProtection(player)

    if mask then
        local itemId, itemKey = filterIdentity(mask)
        local md = mask:getModData()
        local filterRemaining = observedCharge or itemCharge(mask)

        -- Inventory synchronization from an owning client can resend an older
        -- copy of worn-item modData.  Persist the authoritative charge against
        -- the item id so a stale full mask can never refill itself on server.
        if itemKey and record.filterItemKey == itemKey and finite(record.filterRemaining) then
            filterRemaining = math.min(filterRemaining, record.filterRemaining)
        end
        if zone and filterRemaining > 0 then
            local duration = multiplier("FilterDurationMultiplier", 1)
            filterRemaining = math.max(0,
                filterRemaining - Constants.FILTER_DRAIN_PER_SECOND * elapsed / duration)
        end

        local modDataChanged = math.abs((tonumber(md.percent) or 1) - filterRemaining) > 0.0000001
        md.percent = filterRemaining
        local conditionChanged = setVisibleFilterCondition(mask, filterRemaining)
        if modDataChanged or conditionChanged then syncItem(player, mask) end

        record.filterRemaining = filterRemaining
        record.filterItemId = itemId
        record.filterItemKey = itemKey
        if filterRemaining > 0 then
            level = 1
        else
            level = player:isGodMod() and 1 or (hasCloth and (1 / 3) or 0)
        end
    end

    if zone and level < 1 then
        local damage = multiplier("ToxicDamageMultiplier", 1)
        record.exposure = math.min(100, record.exposure + Constants.EXPOSURE_PER_SECOND * elapsed * damage * (1 - level))
        if record.exposure >= 100 then
            record.awaitingRespawn = true
            kill(player)
        end
    elseif not zone then
        record.exposure = math.max(0, record.exposure - Constants.EXPOSURE_DECAY_PER_SECOND * elapsed)
    end

    updateSurfaceContamination(player, record, zone, elapsed, scanCarried, carriedElapsed)

    record.inZone = zone ~= nil
    record.protection = level
    return record
end

local function sendStatus(player, record)
    if not isServer() or not player or not record then return end
    sendServerCommand(player, Constants.NETWORK_MODULE, "exposureStatus", {
        inZone = record.inZone == true,
        exposure = record.exposure or 0,
        protection = record.protection or 0,
        filterRemaining = record.filterRemaining,
        filterItemId = record.filterItemId,
        surfaceContamination = record.surfaceContamination or 0,
        gearContamination = record.gearContamination or 0,
        surfaceClass = ContaminationModel.classify(record.surfaceContamination),
    })
end

function Server.refreshZones()
    refreshZones()
end

function Server.ensureZone(name, bounds)
    if type(name) ~= "string" or type(bounds) ~= "table" then return false, "invalid_zone" end
    local candidate = {
        [name] = {
            startX=bounds.startX,
            startY=bounds.startY,
            endX=bounds.endX,
            endY=bounds.endY,
        },
    }
    if #sanitizeZones(candidate) ~= 1 then return false, "invalid_zone" end
    local zones = ModData.getOrCreate(Constants.ZONES_KEY)
    zones[name] = candidate[name]
    refreshZones()
    if isServer() then ModData.transmit(Constants.ZONES_KEY) end
    return true
end

function Server.removeZone(name)
    if type(name) ~= "string" then return false end
    local zones = ModData.getOrCreate(Constants.ZONES_KEY)
    zones[name] = nil
    refreshZones()
    if isServer() then ModData.transmit(Constants.ZONES_KEY) end
    return true
end

function Server.getPlayerRecord(player)
    if not Server.state or not player then return nil end
    local username = type(player) == "string" and player or player:getUsername()
    local record = Server.state.players[username]
    if type(record) ~= "table" then
        record = { exposure=0, surfaceContamination=0 }
        Server.state.players[username] = record
    end
    return record
end

function Server.setPlayerSurfaceContamination(player, value, contaminateGear)
    local record = Server.getPlayerRecord(player)
    if not record then return false end
    value = ContaminationModel.clamp(value)
    record.surfaceContamination = value
    local maximum = 0
    if type(player) ~= "string" and contaminateGear then
        for _, item in ipairs(collectWornItems(player)) do
            setItemContamination(player, item, value, true)
            maximum = math.max(maximum, value)
        end
    else
        maximum = ContaminationModel.clamp(record.gearContamination)
    end
    record.gearContamination = maximum
    if type(player) ~= "string" then sendStatus(player, record) end
    return true
end

function Server.applySurfaceContact(player, sourceContamination, fraction)
    local record = Server.getPlayerRecord(player)
    if not record then return false end
    record.surfaceContamination = ContaminationModel.contact(
        record.surfaceContamination,
        sourceContamination,
        fraction
    )
    return true
end

function Server.cleanPlayer(player, bodyRemoval, gearRemoval, onlyMostContaminated)
    local record = Server.getPlayerRecord(player)
    if not record or type(player) == "string" then return false, "player_unavailable" end

    record.surfaceContamination = ContaminationModel.clean(record.surfaceContamination, bodyRemoval)
    local wornItems = collectCarriedItems(player, Constants.MAX_CARRIED_ITEMS_PER_SCAN)
    if #wornItems == 0 then wornItems = collectWornItems(player) end
    local selected = nil
    if onlyMostContaminated then
        local highest = 0
        for _, item in ipairs(wornItems) do
            local value = itemContamination(item)
            if value > highest then highest = value; selected = item end
        end
    end

    local maximum = 0
    local cleanedItems = 0
    for _, item in ipairs(wornItems) do
        local current = itemContamination(item)
        if not onlyMostContaminated or item == selected then
            local cleaned = ContaminationModel.clean(current, gearRemoval)
            if setItemContamination(player, item, cleaned, true) then cleanedItems = cleanedItems + 1 end
            current = cleaned
        end
        maximum = math.max(maximum, current)
    end
    record.gearContamination = maximum
    sendStatus(player, record)
    return true, cleanedItems
end

function Server.update()
    if not Server.state then return end
    local now = getTimestampMs()
    if Server.lastTickMs == 0 then Server.lastTickMs = now; return end
    local elapsed = math.min(5, math.max(0, (now - Server.lastTickMs) / 1000))
    if elapsed < 0.9 then return end
    Server.lastTickMs = now
    Server.statusAccumulator = Server.statusAccumulator + elapsed
    local sendNow = Server.statusAccumulator >= Constants.STATUS_INTERVAL_SECONDS

    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        local record = updatePlayer(player, elapsed, sendNow, Server.statusAccumulator)
        if sendNow then sendStatus(player, record) end
    end
    if sendNow then Server.statusAccumulator = 0 end
end

local function isAdmin(player)
    return player and player:isAccessLevel("admin")
end

local function commandResult(player, ok, action, code)
    if player and isServer() then
        sendServerCommand(player, Constants.NETWORK_MODULE, "zoneCommandResult", {
            ok=ok == true,
            action=action,
            code=code,
            zoneCount=#Server.zones,
        })
    end
end

function Server.onClientCommand(module, command, player, args)
    if module ~= Constants.NETWORK_MODULE then return end
    if command == "requestStatus" then
        local record = player and Server.state.players[player:getUsername()]
        if player and type(record) == "table" and record.awaitingRespawn and not player:isDead() then
            record = { exposure=0, surfaceContamination=0 }
            Server.state.players[player:getUsername()] = record
            print("[BunkerCampaignToxicMP] exposure reset on character ready player=" .. player:getUsername())
        end
        sendStatus(player, record or { exposure=0, surfaceContamination=0 })
        return
    end
    if not isAdmin(player) then
        print("[BunkerCampaignToxicMP] rejected command=" .. tostring(command) .. " player=" .. tostring(player and player:getUsername()))
        commandResult(player, false, command, "admin_required")
        return
    end

    local zones = ModData.getOrCreate(Constants.ZONES_KEY)
    if command == "addZone" and type(args) == "table" then
        local name = type(args.name) == "string" and args.name or nil
        local ok = name and Server.ensureZone(name, args)
        if not ok then
            commandResult(player, false, command, "invalid_zone")
            return
        end
    elseif command == "removeZone" and type(args) == "table" and type(args.name) == "string" then
        Server.removeZone(args.name)
    elseif command ~= "refreshZones" then
        commandResult(player, false, command, "unknown_command")
        return
    end
    refreshZones()
    ModData.transmit(Constants.ZONES_KEY)
    print("[BunkerCampaignToxicMP] command=" .. tostring(command)
        .. " player=" .. player:getUsername() .. " zones=" .. tostring(#Server.zones))
    commandResult(player, true, command, nil)
end

function Server.initialize(isNewGame)
    ModData.getOrCreate(Constants.ZONES_KEY)
    Server.state = ModData.getOrCreate(Constants.STATE_KEY)
    local storedVersion = tonumber(Server.state.version) or 0
    Server.state.version = Constants.STATE_VERSION
    if type(Server.state.players) ~= "table" then Server.state.players = {} end
    for _, record in pairs(Server.state.players) do
        if type(record) == "table" then
            record.exposure = math.max(0, math.min(100, tonumber(record.exposure) or 0))
            record.surfaceContamination = ContaminationModel.clamp(record.surfaceContamination)
            record.gearContamination = ContaminationModel.clamp(record.gearContamination)
        end
    end
    if storedVersion < Constants.STATE_VERSION then
        for _, record in pairs(Server.state.players) do
            if type(record) == "table" and (tonumber(record.exposure) or 0) >= 100 then
                record.awaitingRespawn = true
            end
        end
    end
    refreshZones()
    if isServer() then
        ModData.transmit(Constants.ZONES_KEY)
        ModData.transmit(Constants.STATE_KEY)
    end
    print("[BunkerCampaignToxicMP] server ready zones=" .. tostring(#Server.zones))
end

function Server.onPlayerDeath(player)
    if not Server.state or not player then return end
    local username = player:getUsername()
    local record = Server.state.players[username]
    if type(record) ~= "table" then record = { exposure=0, surfaceContamination=0 }; Server.state.players[username] = record end
    record.awaitingRespawn = true
end

Events.OnInitGlobalModData.Add(Server.initialize)
Events.OnTick.Add(Server.update)
Events.OnClientCommand.Add(Server.onClientCommand)
if Events.OnPlayerDeath then Events.OnPlayerDeath.Add(Server.onPlayerDeath) end

BunkerCampaignToxicMP.Server = Server
return Server
