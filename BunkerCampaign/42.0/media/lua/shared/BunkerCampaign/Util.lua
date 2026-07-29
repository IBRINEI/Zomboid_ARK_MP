require "BunkerCampaign/Constants"

BunkerCampaign = BunkerCampaign or {}

local Util = {}

function Util.clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function Util.isFiniteNumber(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Util.numberOr(value, fallback, minimum, maximum)
    if not Util.isFiniteNumber(value) then return fallback end
    if minimum ~= nil and maximum ~= nil then
        return Util.clamp(value, minimum, maximum)
    end
    return value
end

function Util.booleanOr(value, fallback)
    if type(value) ~= "boolean" then return fallback end
    return value
end

function Util.worldAgeHours()
    if getGameTime then
        local gameTime = getGameTime()
        if gameTime then return gameTime:getWorldAgeHours() end
    end
    return 0
end

function Util.actorName(player)
    if player and player.getUsername then
        return player:getUsername()
    end
    return "system"
end

function Util.round(value, places)
    local multiplier = 10 ^ (places or 0)
    return math.floor(value * multiplier + 0.5) / multiplier
end

BunkerCampaign.Util = Util
return Util
