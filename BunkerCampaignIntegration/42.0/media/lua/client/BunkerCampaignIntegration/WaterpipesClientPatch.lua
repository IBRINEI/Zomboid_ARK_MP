require "Actions/TARepairPump"
require "TimedActions/ISTakeWaterAction"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local function effectiveWaterTaint(object, fallback)
    local md = object and object.getModData and object:getModData() or nil
    local medium = md and md.BunkerCampaignWaterMedium or nil
    if medium == "TaintedWater" then return true end
    if medium == "Water" then return false end
    if type(fallback) == "boolean" then return fallback end
    return object and object.isTaintedWater and object:isTaintedWater() or false
end

BunkerCampaignIntegration.effectiveWaterTaint = effectiveWaterTaint

-- WaterPipes synchronizes object ModData in multiplayer, while the legacy
-- sink taint flag lives in shared sprite properties and is not replicated per
-- object.  Feed the authoritative per-object medium into the vanilla water
-- action without mutating a sprite used by unrelated sinks.
if ISTakeWaterAction and not ISTakeWaterAction.BunkerCampaignWaterMediumPatched then
    local originalNew = ISTakeWaterAction.new

    function ISTakeWaterAction:new(character, item, waterObject, waterTaintedCL)
        return originalNew(self, character, item, waterObject,
            effectiveWaterTaint(waterObject, waterTaintedCL))
    end

    ISTakeWaterAction.BunkerCampaignWaterMediumPatched = true
end

-- WaterPipes 42.19 increments pump efficiency only in the client's ModData
-- during TARepairPump.  Starting the pump later causes the authoritative
-- server copy to overwrite that local repair.  Forward the completed value
-- through WaterPipes' existing PumpMod command without changing the source mod.
if TARepairPump and not TARepairPump.BunkerCampaignRepairSyncPatched then
    local originalPerform = TARepairPump.perform

    function TARepairPump:perform()
        local object = self.object
        local x = object and object:getX() or nil
        local y = object and object:getY() or nil
        local z = object and object:getZ() or nil
        originalPerform(self)

        if isClient() and x and y and z and type(WPVirtual) == "table"
            and type(WPVirtual.PumpGet) == "function" then
            local pump = WPVirtual.PumpGet(x, y, z)
            if pump and tonumber(pump.efficiency) then
                sendClientCommand(self.character, "Commands", "PumpMod", {
                    x=x, y=y, z=z, efficiency=tonumber(pump.efficiency),
                })
            end
        end
    end

    TARepairPump.BunkerCampaignRepairSyncPatched = true
end
