BWOARooms = BWOARooms or {}

BWOARooms.BathroomMale = {}

BWOARooms.BathroomMale.Init = function ()
    BWOARooms.BathroomMale.name = "BATHROOM"
    BWOARooms.BathroomMale.x1 = 9948
    BWOARooms.BathroomMale.x2 = 9956
    BWOARooms.BathroomMale.y1 = 12643
    BWOARooms.BathroomMale.y2 = 12650
    BWOARooms.BathroomMale.z = -4
    BWOARooms.BathroomMale.ambience = ""

    BWOARooms.BathroomMale.vents = {
        {x=9952.5, y=12650, z=-4},
        {x=9949, y=12643, z=-4},
    }
end

BWOARooms.BathroomMale.Build = function ()
    BWOARooms.BathroomMale.Init()

    BWOABuildTools.RemoveObject(9952, 12645, -4, "fixtures_bathroom_01_9")
    BWOABuildTools.RemoveObject(9952, 12646, -4, "fixtures_bathroom_01_9")
    BWOABuildTools.RemoveObject(9952, 12647, -4, "fixtures_bathroom_01_9")

    BWOAPrepareTools.DarkenLight(9956, 12650, -4)
    BWOAPrepareTools.DarkenLight(9951, 12649, -4)

    BWOABuildTools.LampOvalN(9950, 12643, -4)
    BWOABuildTools.LampOvalS(9950, 12650, -4)
    BWOABuildTools.LampOvalN(9955, 12643, -4)
    BWOABuildTools.LampOvalS(9955, 12650, -4)

    BWOABuildTools.VentW(9949, 12643, -4)
end

BWOARooms.BathroomMale.SetEmitters = function ()
    BWOARooms.BathroomMale.Init()
    BWOASound.AddToObject({x=9948, y=12645, z=-4, sound="AmbientWaterDrops"})
end

BWOARooms.BathroomMale.Prepare = function ()
    BWOARooms.BathroomMale.Init()

end


