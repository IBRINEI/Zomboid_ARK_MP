require "BunkerCampaignIntegration/Constants"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local Constants = BunkerCampaignIntegration.Constants
local Rules = Constants.DECONTAMINATION
local Effects = {
    activeCycleId = nil,
    visualRunning = false,
    entries = {},
}

local function nearby(player)
    if not player or math.abs(player:getZ() - Rules.ROOM.z) >= 0.1 then return false end
    local cx = (Rules.ROOM.x1 + Rules.ROOM.x2) / 2
    local cy = (Rules.ROOM.y1 + Rules.ROOM.y2) / 2
    return math.abs(player:getX() - cx) < 20 and math.abs(player:getY() - cy) < 20
end

local function startCycleEffect(cycle)
    local player = getSpecificPlayer(0)
    if not nearby(player) then return end
    local duration = math.max(1, tonumber(cycle.remainingSeconds) or tonumber(cycle.durationSeconds) or 10)
    local repetitions = math.max(2, math.ceil(duration))
    for _ = 1, 20 do
        Effects.entries[#Effects.entries + 1] = {
            x=Rules.ROOM.x1 + ZombRand(math.max(1, Rules.ROOM.x2 - Rules.ROOM.x1)),
            y=Rules.ROOM.y1 + ZombRand(math.max(1, Rules.ROOM.y2 - Rules.ROOM.y1)),
            z=Rules.ROOM.z,
            size=400,
            frame=1 + ZombRand(60),
            frameCnt=60,
            repetition=1,
            repetitions=repetitions,
        }
    end
    local emitter = player:getEmitter()
    if emitter then emitter:playSound("BunkerDecontaminationMist") end
end

local function onServerCommand(module, command, args)
    if module ~= Constants.DECON_NETWORK_MODULE or command ~= "deconStatus" or type(args) ~= "table" then return end
    local cycle = args.activeCycle
    local cycleId = type(cycle) == "table" and tonumber(cycle.id) or nil
    if cycleId and args.status == "running"
        and (cycleId ~= Effects.activeCycleId or not Effects.visualRunning) then
        Effects.activeCycleId = cycleId
        Effects.visualRunning = true
        startCycleEffect(cycle)
    elseif cycleId and args.status ~= "running" then
        Effects.activeCycleId = cycleId
        Effects.visualRunning = false
        Effects.entries = {}
    elseif not cycleId then
        Effects.activeCycleId = nil
        Effects.visualRunning = false
        Effects.entries = {}
    end
end

local function draw()
    if #Effects.entries == 0 or not isIngameState() then return end
    local player = getSpecificPlayer(0)
    if not nearby(player) then return end
    local playerNum = player:getPlayerNum()
    local zoom = getCore():getZoom(playerNum)
    for index = #Effects.entries, 1, -1 do
        local effect = Effects.entries[index]
        if effect.frame > effect.frameCnt then
            effect.frame = 1
            effect.repetition = effect.repetition + 1
        end
        if effect.repetition > effect.repetitions then
            table.remove(Effects.entries, index)
        else
            local size = effect.size / zoom
            local offset = (size / 2) - (3 * effect.z)
            local screenX = isoToScreenX(playerNum, effect.x, effect.y, effect.z) - offset
            local screenY = isoToScreenY(playerNum, effect.x, effect.y, effect.z) - offset
            local frame = string.format("%03d", effect.frame)
            local texture = getTexture("media/textures/FX/mist/" .. frame .. ".png")
            if texture then
                local progress = ((effect.repetition - 1) * effect.frameCnt + effect.frame)
                    / (effect.repetitions * effect.frameCnt)
                local alpha = math.sin(math.min(1, progress) * math.pi) * 0.35
                UIManager.DrawTexture(texture, screenX, screenY, size, size, alpha)
            end
            effect.frame = effect.frame + 1
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)
Events.OnPreUIDraw.Add(draw)

BunkerCampaignIntegration.DecontaminationEffects = Effects
return Effects
