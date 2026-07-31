require "Actions/TARepairPump"

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
