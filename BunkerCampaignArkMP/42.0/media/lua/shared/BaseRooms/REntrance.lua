BWOARooms = BWOARooms or {}

BWOARooms.Entrance = {}

BWOARooms.Entrance.Init = function ()
    BWOARooms.Entrance.name = "ENTRANCE"
    BWOARooms.Entrance.x1 = 9918
    BWOARooms.Entrance.x2 = 9943
    BWOARooms.Entrance.y1 = 12623
    BWOARooms.Entrance.y2 = 12627
    BWOARooms.Entrance.z = -4
    BWOARooms.Entrance.ambience = ""

    BWOARooms.Entrance.vents = {}

    BWOARooms.Entrance.els = {}

    BWOARooms.Entrance.doors = {
        -- {x = 9926, y = 12625, z = 0},
        {
            x = 9924, 
            y = 12625, 
            z = -4,
            panels = {
                {x = 9924, y = 12624, z = -4}
            }
        },
        {
            x = 9934, 
            y = 12625, 
            z = -4,
            panels = {
                {x = 9933, y = 12624, z = -4},
                {x = 9934, y = 12624, z = -4},
            }
        },
        {
            x = 9944, 
            y = 12625, 
            z = -4,
            panels = {
                {x = 9943, y = 12624, z = -4},
            }
        },
    }
end

BWOARooms.Entrance.Build = function ()
    BWOARooms.Entrance.Init()

    BWOAPrepareTools.DarkenLight(9925, 12624, -4)

    BWOABuildTools.ELS(BWOARooms.Entrance.els)

    BWOABuildTools.LampOvalN(9938, 12624, -4)
    BWOABuildTools.LampOvalN(9928, 12624, -4)

    -- door panels
    for _, doorConf in ipairs(BWOARooms.Entrance.doors) do
        for _, panel in ipairs(doorConf.panels) do
            BWOABuildTools.WallPanel(panel.x, panel.y, panel.z)
        end
    end

    BWOABuildTools.RemoveObject(9925, 12624, -4, "walls_garage_01_37")
    BWOABuildTools.WindowFrame(9925, 12624, -4, "theark_01_25", true)
    BWOABuildTools.Window(9925, 12624, -4, "theark_01_26", true)

    BWOABuildTools.RemoveObject(9932, 12624, -4, "walls_garage_01_37")
    BWOABuildTools.WindowFrame(9932, 12624, -4, "theark_01_25", true)
    BWOABuildTools.Window(9932, 12624, -4, "theark_01_26", true)

    BWOABuildTools.RemoveObject(9935, 12624, -4, "walls_garage_01_37")
    BWOABuildTools.WindowFrame(9935, 12624, -4, "theark_01_25", true)
    BWOABuildTools.Window(9935, 12624, -4, "theark_01_26", true)

    BWOABuildTools.RemoveObject(9941, 12624, -4, "walls_garage_01_37")
    BWOABuildTools.WindowFrame(9941, 12624, -4, "theark_01_25", true)
    BWOABuildTools.Window(9941, 12624, -4, "theark_01_26", true)

end

BWOARooms.Entrance.SetEmitters = function ()
    BWOARooms.Entrance.Init()
end

BWOARooms.Entrance.SetFlickers = function ()
    BWOARooms.Entrance.Init()
    BWOALights.AddFlicker({x=9928, y=12624, z=-4})
end

BWOARooms.Entrance.Prepare = function ()
    BWOARooms.Entrance.Init()
end

BWOARooms.Entrance.Logic = function ()
    -- The original client/NPC-driven door controller is not safe in MP.
end
