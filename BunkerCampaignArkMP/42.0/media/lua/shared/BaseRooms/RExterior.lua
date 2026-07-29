BWOARooms = BWOARooms or {}

BWOARooms.Exterior = {}

BWOARooms.Exterior.Init = function ()
    BWOARooms.Exterior.name = "AIRINTAKE"
    BWOARooms.Exterior.x1 = 9940
    BWOARooms.Exterior.x2 = 9941
    BWOARooms.Exterior.y1 = 12633
    BWOARooms.Exterior.y2 = 12634
    BWOARooms.Exterior.z = 0
    BWOARooms.Exterior.ambience = ""
end

BWOARooms.Exterior.Build = function ()
    BWOARooms.Exterior.Init()

    -- air intakes
    BWOABuildTools.Generic(9940, 12633, 0, "theark_01_5")
    BWOABuildTools.Generic(9940, 12634, 0, "theark_01_6")
    BWOABuildTools.Generic(9941, 12633, 0, "theark_01_5")
    BWOABuildTools.Generic(9941, 12634, 0, "theark_01_6")

    -- fuel intake
    BWOABuildTools.Generic(9926, 12617, 0, "theark_01_7")
    BWOABuildTools.Generic(9927, 12617, 0, "theark_01_7")
end

BWOARooms.Exterior.SetEmitters = function ()
    BWOARooms.Exterior.Init()
end

BWOARooms.Exterior.SetAnims = function ()
    BWOARooms.Exterior.Init()

    

end

BWOARooms.Exterior.SetFlickers = function ()
    BWOARooms.Exterior.Init()
end

BWOARooms.Exterior.Prepare = function ()
    BWOARooms.Exterior.Init()
end


