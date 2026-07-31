isClient = function() return false end
isServer = function() return true end

local function event()
    local value = { handlers={} }
    value.Add = function(handler) value.handlers[#value.handlers + 1] = handler end
    return value
end
Events = { OnInitGlobalModData=event() }

local persisted = {
    ["BunkerCampaign.IntegrationState"]={},
    WaterPipes={
        Pumps={ ["9950-12616--4"]={x=9950,y=12616,z=-4,efficiency=100,filter=100,active=false,source="TaintedWater"} },
        Pipes={}, Valves={}, Flowmeters={}, Sprinklers={}, Buildings={},
        Barrels={ clean={x=9952,y=12603,z=-5,w=1000,wmax=2000,m="Water"} },
    },
}
ModData = {
    getOrCreate=function(key) persisted[key] = persisted[key] or {}; return persisted[key] end,
}
TransmitWPModData = function() end

local physicalAmount, physicalMedium = 0, nil
local physicalMd = {waterAmount=0,waterMaxAmount=20}
local physicalObject = {
    getFluidAmount=function() return physicalAmount end,
    getFluidCapacity=function() return 20 end,
    getModData=function() return physicalMd end,
    isTaintedWater=function() return physicalMedium == "TaintedWater" end,
    emptyFluid=function() physicalAmount, physicalMedium = 0, nil end,
    addFluid=function(self, medium, amount) physicalMedium, physicalAmount = medium, amount end,
    transmitModData=function() end,
    sync=function() end,
}
FluidType = {Water="Water",TaintedWater="TaintedWater"}
function WaterServiceEnablePhysicalReceiver()
    persisted.WaterPipes.Barrels.physical = {
        x=9953,y=12603,z=-5,w=0,wmax=2000,m=nil,
    }
    getCell=function()
        return {getGridSquare=function(self, x, y, z)
            if x == 9953 and y == 12603 and z == -5 then return {receiver=physicalObject} end
            return nil
        end}
    end
    WPIso={GetBarrel=function(square) return square and square.receiver or nil end}
end
function WaterServicePhysicalState() return physicalAmount, physicalMedium end

local waterState = { telemetry={consumedLiters=0,lastTransactionId=""} }
BunkerCampaign.CampaignState = {
    get=function() return {bunker={modules={water=waterState}}} end,
    setWaterSnapshot=function() end,
}
