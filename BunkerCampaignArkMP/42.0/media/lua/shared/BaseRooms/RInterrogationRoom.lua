BWOARooms = BWOARooms or {}

BWOARooms.InterrogationRoom = {}

BWOARooms.InterrogationRoom.Init = function ()
    BWOARooms.InterrogationRoom.name = "MEETING_ROOM"
    BWOARooms.InterrogationRoom.x1 = 9959
    BWOARooms.InterrogationRoom.x2 = 9965
    BWOARooms.InterrogationRoom.y1 = 12631
    BWOARooms.InterrogationRoom.y2 = 12635
    BWOARooms.InterrogationRoom.z = -4
    BWOARooms.InterrogationRoom.ambience = ""

    BWOARooms.InterrogationRoom.vents = {
        {x=9959, y=12632.5, z=-4},
    }

    BWOARooms.InterrogationRoom.els = {}
    for x=BWOARooms.InterrogationRoom.x1, BWOARooms.InterrogationRoom.x2 do
        table.insert(BWOARooms.InterrogationRoom.els, {dir="N", x=x, y=BWOARooms.InterrogationRoom.y1, z=-4})
        table.insert(BWOARooms.InterrogationRoom.els, {dir="S", x=x, y=BWOARooms.InterrogationRoom.y2, z=-4})
    end

    for y=BWOARooms.InterrogationRoom.y1, BWOARooms.InterrogationRoom.y2 do
        if y ~= BWOARooms.InterrogationRoom.y1 + 2 then
            table.insert(BWOARooms.InterrogationRoom.els, {dir="W", x=BWOARooms.InterrogationRoom.x1, y=y, z=-4})
        end
        table.insert(BWOARooms.InterrogationRoom.els, {dir="E", x=BWOARooms.InterrogationRoom.x2, y=y, z=-4})
    end
    
end

BWOARooms.InterrogationRoom.Build = function ()
    BWOARooms.InterrogationRoom.Init()
    BWOAPrepareTools.DarkenLight(9959, 12634, -4)

    BWOABuildTools.ELS(BWOARooms.InterrogationRoom.els)

    BWOABuildTools.EmergencyExitW(9959, 12633, -4)

    BWOABuildTools.LampOvalN(9960, 12631, -4)
    BWOABuildTools.LampOvalN(9964, 12631, -4)

    BWOABuildTools.RemoveObject(9964, 12633, -4, "Chair")
    BWOABuildTools.Generic(9964, 12633, -4, "appliances_com_01_46")

    BWOABuildTools.Generic(9959, 12632, -4, "furniture_tables_low_01_18")
    BWOABuildTools.TV(9959, 12632, -4, "appliances_television_01_5")



end

BWOARooms.InterrogationRoom.SetEmitters = function ()
    BWOARooms.InterrogationRoom.Init()
end

BWOARooms.InterrogationRoom.SetFlickers = function ()
    BWOARooms.InterrogationRoom.Init()
end

BWOARooms.InterrogationRoom.Prepare = function ()
    BWOARooms.InterrogationRoom.Init()



    BWOAPrepareTools.AddWorldItem(9961, 12633, -4, "Base.CameraExpensive", {x=0.64, y=0.80, z=0.33, rx=0, ry=0, rz=340})
    BWOAPrepareTools.AddWorldItem(9961, 12633, -4, "Base.CameraFilm", {x=0.82, y=0.80, z=0.33, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9961, 12633, -4, "Base.CameraFilm", {x=0.80, y=0.70, z=0.33, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9961, 12633, -4, "Base.Paperwork", {x=0.47, y=0.31, z=0.33, rx=0, ry=0, rz=340})
    BWOAPrepareTools.AddWorldItem(9961, 12633, -4, "Base.Paperwork", {x=0.59, y=0.29, z=0.33, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9961, 12633, -4, "Base.Pencil", {x=0.73, y=0.37, z=0.33, rx=0, ry=0, rz=240})

    BWOAPrepareTools.AddWorldItem(9962, 12633, -4, "Base.SheetPaper2", {x=0.44, y=0.69, z=0.33, rx=0, ry=0, rz=30})
    BWOAPrepareTools.AddWorldItem(9962, 12633, -4, "Base.Pen", {x=0.38, y=0.22, z=0.33, rx=0, ry=0, rz=285})
    BWOAPrepareTools.AddWorldItem(9962, 12633, -4, "Base.RedPen", {x=0.42, y=0.27, z=0.33, rx=0, ry=0, rz=275})
    BWOAPrepareTools.AddWorldItem(9962, 12633, -4, "Base.Pencil", {x=0.76, y=0.80, z=0.33, rx=0, ry=0, rz=85})
    BWOAPrepareTools.AddWorldItem(9962, 12633, -4, "Base.Pencil", {x=0.78, y=0.78, z=0.33, rx=0, ry=0, rz=85})
    BWOAPrepareTools.AddWorldItem(9962, 12633, -4, "Base.PaperclipBox", {x=0.80, y=0.55, z=0.33, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9962, 12633, -4, "Base.Paperwork", {x=0.77, y=0.29, z=0.33, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9962, 12633, -4, "Base.Paperwork", {x=0.21, y=0.54, z=0.33, rx=0, ry=0, rz=130})
    BWOAPrepareTools.AddWorldItem(9962, 12633, -4, "Base.Paperwork", {x=0.31, y=0.38, z=0.33, rx=0, ry=0, rz=355})
    BWOAPrepareTools.AddWorldItem(9962, 12633, -4, "Base.Paperwork", {x=0.82, y=0.30, z=0.33, rx=0, ry=0, rz=345})

    BWOAPrepareTools.AddWorldItem(9963, 12633, -4, "Base.Clipboard", {x=0.42, y=0.33, z=0.33, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9963, 12633, -4, "Base.Mugl", {x=0.14, y=0.45, z=0.33, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9963, 12633, -4, "Base.TissueBox", {x=0.62, y=0.69, z=0.33, rx=0, ry=0, rz=90})

    BWOAPrepareTools.AddWorldItem(9965, 12631, -4, "Base.Extinguisher", {x=0.61, y=0.20, z=0.00, rx=0, ry=0, rz=0})

    local key = BanditCompatibility.InstanceItem("Base.Key1")
    local keyid = getCell():getGridSquare(9969, 12634, -5):getBuildingDef():getKeyId()
    key:setKeyId(keyid)
    key:setName(getText("IGUI_Artifact_ServiceTunnelsKey"))
    BWOAPrepareTools.AddItemsToContainer(9959, 12635, -4, {key}, "Cabinet")

    local item = BanditCompatibility.InstanceItem("Base.VHS_Home")
    local mediaRecorder = ZomboidRadio.getInstance():getRecordedMedia()
    local mediaData = mediaRecorder:getMediaData("d5fe3df0-5e3b-0146-0001-000000000000")
    item:setRecordedMediaData(mediaData)
    item:setName("Survivor ID #146 – Recording 1")
    BWOAPrepareTools.AddWorldItemSpecial(9963, 12633, -4, item, {x=0.34, y=0.79, z=0.33, rx=0, ry=0, rz=230})

    local items = {"Base.MarchRidgeMap", "Base.MuldraughMap", "Base.RosewoodMap", "Base.WestpointMap"}
    BWOAPrepareTools.AddItemsToContainer(9959, 12631, -4, items, "Cabinet")

    local tapesArk = {
        -- {id="d445445a-1a1a-0111-0001-000000000000"}, -- ark briefing
        -- {id="d565951b-1b1b-0111-0001-000000000000"}, -- ark nuclear winter
        {id="d468123f-899c-4488-902e-000000000000"}, -- ark medical 1
        {id="d3950c33-4eec-4477-b032-000000000000"}, -- ark medical 2
        {id="7fbeacb8-0620-4b8f-9638-000000000000"}, -- ark medical 3
        {id="d8a8fa8f-be1a-462d-8377-000000000000"}, -- ark medical 4
        {id="6cca967b-3893-410e-a5f4-000000000000"}, -- ark engineering 1 (gx9)
    }

    local mediaRecorder = ZomboidRadio.getInstance():getRecordedMedia()
    for _, tapeConf in pairs(tapesArk) do
        local item = BanditCompatibility.InstanceItem("Base.VHS_Home")
        local mediaData = mediaRecorder:getMediaData(tapeConf.id)
        item:setRecordedMediaData(mediaData)
        BWOAPrepareTools.AddItemsToContainer(9959, 12631, -4, {item}, "Cabinet", true)
    end
end


