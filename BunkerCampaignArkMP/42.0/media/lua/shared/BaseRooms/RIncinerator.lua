BWOARooms = BWOARooms or {}

BWOARooms.Incinerator = {}

BWOARooms.Incinerator.Init = function ()
    BWOARooms.Incinerator.name = "INCINERATOR_ROOM"
    BWOARooms.Incinerator.x1 = 9966
    BWOARooms.Incinerator.x2 = 9970
    BWOARooms.Incinerator.y1 = 12637
    BWOARooms.Incinerator.y2 = 12640
    BWOARooms.Incinerator.z = -4
    BWOARooms.Incinerator.ambience = ""

    BWOARooms.Incinerator.vents = {
        {x=9969, y=12637.5, z=-4},
    }

    BWOARooms.Incinerator.els = {}
    for x=BWOARooms.Incinerator.x1, BWOARooms.Incinerator.x2 do
        table.insert(BWOARooms.Incinerator.els, {dir="N", x=x, y=BWOARooms.Incinerator.y1, z=-4})
        if x ~= 9968 then
            table.insert(BWOARooms.Incinerator.els, {dir="S", x=x, y=BWOARooms.Incinerator.y2, z=-4})
        end
    end

    for y=BWOARooms.Incinerator.y1, BWOARooms.Incinerator.y2 do
        table.insert(BWOARooms.Incinerator.els, {dir="W", x=BWOARooms.Incinerator.x1, y=y, z=-4})
        table.insert(BWOARooms.Incinerator.els, {dir="E", x=BWOARooms.Incinerator.x2, y=y, z=-4})
    end
end

BWOARooms.Incinerator.Build = function ()
    BWOARooms.Incinerator.Init()

    BWOAPrepareTools.DarkenLight(9969, 12640, -4)

    BWOABuildTools.ELS(BWOARooms.Incinerator.els)

    BWOABuildTools.LampOvalN(9967, 12637, -4)

    BWOABuildTools.VentW(9969, 12637, -4)

    BWOABuildTools.RemoveObject(9966, 12637, -4, "Shelves")
    BWOABuildTools.RemoveObject(9966, 12638, -4, "Shelves")
    BWOABuildTools.RemoveObject(9966, 12639, -4, "Shelves")
    BWOABuildTools.RemoveObject(9966, 12640, -4, "Shelves")

    BWOABuildTools.Generic(9966, 12637, -4, "industry_02_55")
    BWOABuildTools.Generic(9966, 12638, -4, "theark_01_8")
    BWOABuildTools.Generic(9966, 12639, -4, "industry_02_62")
    BWOABuildTools.Generic(9966, 12640, -4, "industry_02_16")

end

BWOARooms.Incinerator.SetEmitters = function ()
    BWOARooms.Incinerator.Init()
end

BWOARooms.Incinerator.Prepare = function ()
    BWOARooms.Incinerator.Init()

    BWOAPrepareTools.AddWorldItem(9966, 12640, -4, "Base.Extinguisher", {x=0.44, y=0.09, z=0.00, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9966, 12640, -4, "Base.Extinguisher", {x=0.73, y=0.58, z=0.00, rx=0, ry=0, rz=0})
end


