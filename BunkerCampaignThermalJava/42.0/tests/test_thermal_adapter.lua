local root = "C:/Users/BRINE/Zomboid/mods/"
package.path = root .. "BunkerCampaignThermalJava/42.0/media/lua/shared/?.lua;" .. package.path

require "BunkerCampaignThermalJava/ThermalOverrideAdapter"

local Adapter = BunkerCampaignThermalJava.ThermalOverrideAdapter
local staged, committed = nil, nil

bcThermalBegin = function() staged = {}; return true end
bcThermalAddRegion = function(roomId, x1, y1, x2, y2, z, temperature)
    staged[#staged + 1] = {
        roomId=roomId, x1=x1, y1=y1, x2=x2, y2=y2, z=z,
        temperature=temperature,
    }
    return true
end
bcThermalCommit = function() committed = staged; return #staged end
bcThermalClear = function() staged, committed = nil, nil end

local heating = {
    averageTemperature=-20,
    rooms={ laboratory={
        temperature=-18.5,
        regions={
            { x1=10, y1=20, x2=11, y2=22, z=-4 },
            { x1=12, y1=21, x2=12, y2=22, z=-4 },
        },
    } },
}

local ok, count = Adapter.apply(heating)
assert(ok and count == 2 and #committed == 2,
    "adapter must atomically publish every room region")
assert(committed[1].roomId == "laboratory" and committed[1].temperature == -18.5,
    "published regions must carry authoritative room temperature")

bcThermalBegin, bcThermalAddRegion, bcThermalCommit, bcThermalClear = nil, nil, nil, nil
local unavailable, reason = Adapter.apply(heating)
assert(unavailable == false and reason == "java_override_unavailable",
    "optional module must fail closed when its Java API is absent")

print("BunkerCampaignThermalJava adapter tests passed")
