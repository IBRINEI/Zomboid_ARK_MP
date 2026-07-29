BWOARooms = BWOARooms or {}

BWOARooms.Chapel = {}

BWOARooms.Chapel.Init = function ()
    BWOARooms.Chapel.name = "CHAPEL"
    BWOARooms.Chapel.x1 = 9965
    BWOARooms.Chapel.x2 = 9970
    BWOARooms.Chapel.y1 = 12628
    BWOARooms.Chapel.y2 = 12632
    BWOARooms.Chapel.z = -4
    BWOARooms.Chapel.ambience = ""

    BWOARooms.Chapel.vents = {
        {x=9968.5, y=12628, z=-4},
    }

    BWOARooms.Chapel.els = {}
    for x=BWOARooms.Chapel.x1, BWOARooms.Chapel.x2 do
        table.insert(BWOARooms.Chapel.els, {dir="N", x=x, y=BWOARooms.Chapel.y1, z=-4})
        table.insert(BWOARooms.Chapel.els, {dir="S", x=x, y=BWOARooms.Chapel.y2, z=-4})
    end

    for y=BWOARooms.Chapel.y1, BWOARooms.Chapel.y2 do
        table.insert(BWOARooms.Chapel.els, {dir="W", x=BWOARooms.Chapel.x1, y=y, z=-4})
        if y ~= 12630 then
            table.insert(BWOARooms.Chapel.els, {dir="E", x=BWOARooms.Chapel.x2, y=y, z=-4})
        end
    end
end

BWOARooms.Chapel.Build = function ()
    BWOARooms.Chapel.Init()

    BWOAPrepareTools.DarkenLight(9970, 12629, -4)

    BWOABuildTools.ELS(BWOARooms.Chapel.els)

    BWOABuildTools.LampOvalN(9966, 12628, -4)
    BWOABuildTools.LampOvalN(9969, 12628, -4)
    BWOABuildTools.LampOvalS(9966, 12632, -4)
    BWOABuildTools.LampOvalS(9969, 12632, -4)

    BWOABuildTools.VentW(9968, 12628, -4)

    for x=BWOARooms.Chapel.x1, BWOARooms.Chapel.x2 do
        for y=BWOARooms.Chapel.y1, BWOARooms.Chapel.y2 do
            BWOABuildTools.RemoveObject(x, y, -4, "Shelves")
        end
    end

    BWOABuildTools.Generic(9965, 12630, -4, "location_community_church_small_01_22") -- cross
    BWOABuildTools.Generic(9966, 12630, -4, "location_community_church_small_01_42") -- altar
    BWOABuildTools.Generic(9966, 12629, -4, "location_community_church_small_01_43") -- altar
    BWOABuildTools.Generic(9968, 12632, -4, "location_community_church_small_01_59") -- pews
    BWOABuildTools.Generic(9968, 12631, -4, "location_community_church_small_01_61")
    BWOABuildTools.Generic(9968, 12629, -4, "location_community_church_small_01_59")
    BWOABuildTools.Generic(9968, 12628, -4, "location_community_church_small_01_61")
    BWOABuildTools.Generic(9970, 12632, -4, "location_community_church_small_01_59")
    BWOABuildTools.Generic(9970, 12631, -4, "location_community_church_small_01_61")
    BWOABuildTools.Generic(9970, 12629, -4, "location_community_church_small_01_59")
    BWOABuildTools.Generic(9970, 12628, -4, "location_community_church_small_01_61")

end

BWOARooms.Chapel.SetEmitters = function ()
    BWOARooms.Chapel.Init()
end

BWOARooms.Chapel.Prepare = function ()
    BWOARooms.Chapel.Init()

    BWOAPrepareTools.AddWorldItem(9967, 12630, -4, "Base.Goblet", {x=0.04, y=0.48, z=0.48, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9967, 12629, -4, "Base.Book_Religion", {x=0.05, y=0.84, z=0.00, rx=0, ry=0, rz=0})

end


