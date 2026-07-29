BWOABuildTools.WaterPump(9950, 12616, -4)

local calls = ArkMPWaterPumpCalls()
assert(ArkMPWaterPumpSquare().object ~= nil, "server must create the water pump object")
assert(calls.complete == 1, "server must transmit the new water pump")
assert(calls.squareChanged == 1, "server must mark the repaired square as changed")
assert(calls.transmitted == 1, "server must transmit authoritative Waterpipes state")
assert(calls.added == 0 and calls.filter == 0 and calls.active == 0,
    "dedicated server must not route pump registration through client commands")
local pump = ArkMPWaterPumpState().Pumps["9950-12616--4"]
assert(pump and pump.filter == 100 and pump.active == true,
    "server must directly register and activate the pump in Waterpipes")

print("BunkerCampaignArkMP dedicated-server water pump tests passed")
