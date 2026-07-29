BWOARooms = BWOARooms or {}

BWOARooms.BathroomFemale = {}

BWOARooms.BathroomFemale.Init = function ()
    BWOARooms.BathroomFemale.name = "BATHROOM"
    BWOARooms.BathroomFemale.x1 = 9948
    BWOARooms.BathroomFemale.x2 = 9956
    BWOARooms.BathroomFemale.y1 = 12600
    BWOARooms.BathroomFemale.y2 = 12608
    BWOARooms.BathroomFemale.z = -4
    BWOARooms.BathroomFemale.ambience = ""

    BWOARooms.BathroomFemale.vents = {
        {x=9952.5, y=12600, z=-4},
        {x=9949, y=12607, z=-4},
    }
end

BWOARooms.BathroomFemale.Build = function ()
    BWOARooms.BathroomFemale.Init()

    BWOAPrepareTools.DarkenLight(9956, 12602, -4)
    BWOAPrepareTools.DarkenLight(9951, 12601, -4)

    BWOABuildTools.LampOvalS(9950, 12607, -4)
    BWOABuildTools.LampOvalN(9950, 12600, -4)
    BWOABuildTools.LampOvalS(9955, 12607, -4)
    BWOABuildTools.LampOvalN(9955, 12600, -4)

    BWOABuildTools.VentW(9952, 12600, -4)
end

BWOARooms.BathroomFemale.SetEmitters = function ()
    BWOARooms.BathroomFemale.Init()
    BWOASound.AddToObject({x=9948, y=12605, z=-4, sound="AmbientWaterDrops"})
end

BWOARooms.BathroomFemale.SetFlickers = function ()
    BWOARooms.BathroomFemale.Init()
    BWOALights.AddFlicker({x=9955, y=12600, z=-4})
end

BWOARooms.BathroomFemale.Prepare = function ()
    BWOARooms.BathroomFemale.Init()
    
end


