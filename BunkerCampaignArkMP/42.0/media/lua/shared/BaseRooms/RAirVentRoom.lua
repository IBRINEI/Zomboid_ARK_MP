BWOARooms = BWOARooms or {}

BWOARooms.AirVentRoom = {}

BWOARooms.AirVentRoom.Init = function ()
    BWOARooms.AirVentRoom.name = "AIRVENTROOM"
    BWOARooms.AirVentRoom.x1 = 9966
    BWOARooms.AirVentRoom.x2 = 9970
    BWOARooms.AirVentRoom.y1 = 12633
    BWOARooms.AirVentRoom.y2 = 12636
    BWOARooms.AirVentRoom.z = -4
    BWOARooms.AirVentRoom.ambience = ""

    BWOARooms.AirVentRoom.vents = {
        {x=9969, y=12637.5, z=-4},
    }

    BWOARooms.AirVentRoom.els = {}
    for x=BWOARooms.AirVentRoom.x1, BWOARooms.AirVentRoom.x2 do
        table.insert(BWOARooms.AirVentRoom.els, {dir="N", x=x, y=BWOARooms.AirVentRoom.y1, z=-4})
        table.insert(BWOARooms.AirVentRoom.els, {dir="S", x=x, y=BWOARooms.AirVentRoom.y2, z=-4})
    end

    for y=BWOARooms.AirVentRoom.y1, BWOARooms.AirVentRoom.y2 do
        table.insert(BWOARooms.AirVentRoom.els, {dir="W", x=BWOARooms.AirVentRoom.x1, y=y, z=-4})
        if y ~= 12635 then
            table.insert(BWOARooms.AirVentRoom.els, {dir="E", x=BWOARooms.AirVentRoom.x2, y=y, z=-4})
        end
    end
end

BWOARooms.AirVentRoom.Build = function ()
    BWOARooms.AirVentRoom.Init()

    BWOAPrepareTools.DarkenLight(9970, 12636, -4)

    BWOABuildTools.ELS(BWOARooms.AirVentRoom.els)

    BWOABuildTools.LampOvalS(9968, 12636, -4)

end

BWOARooms.AirVentRoom.SetEmitters = function ()
    BWOARooms.AirVentRoom.Init()
end

BWOARooms.AirVentRoom.Prepare = function ()
    BWOARooms.AirVentRoom.Init()

    local items
    items = {["Base.Wrench"] = 1, ["Base.Axe"] = 1}
    BWOAPrepareTools.AddItemsToContainer(9969, 12633, -4, items, "Shelves")

end


