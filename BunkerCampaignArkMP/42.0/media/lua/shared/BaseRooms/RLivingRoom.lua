BWOARooms = BWOARooms or {}

BWOARooms.LivingRoom = {}

BWOARooms.LivingRoom.Init = function ()
    BWOARooms.LivingRoom.name = "LIVING_ROOM"
    BWOARooms.LivingRoom.x1 = 9973
    BWOARooms.LivingRoom.x2 = 9980
    BWOARooms.LivingRoom.y1 = 12618
    BWOARooms.LivingRoom.y2 = 12632
    BWOARooms.LivingRoom.z = -4
    BWOARooms.LivingRoom.ambience = ""

    BWOARooms.LivingRoom.vents = {
        {x=9973, y=12629, z=-4},
        {x=9973, y=12621, z=-4},
    }

    BWOARooms.LivingRoom.els = {}
    for x=BWOARooms.LivingRoom.x1, BWOARooms.LivingRoom.x2 do
        table.insert(BWOARooms.LivingRoom.els, {dir="N", x=x, y=BWOARooms.LivingRoom.y1, z=-4})
        table.insert(BWOARooms.LivingRoom.els, {dir="S", x=x, y=BWOARooms.LivingRoom.y2, z=-4})
    end

    for y=BWOARooms.LivingRoom.y1, BWOARooms.LivingRoom.y2 do
        if y ~= BWOARooms.LivingRoom.y1 + 2 and y ~= BWOARooms.LivingRoom.y2 - 2 then
            table.insert(BWOARooms.LivingRoom.els, {dir="W", x=BWOARooms.LivingRoom.x1, y=y, z=-4})
        end
        
        table.insert(BWOARooms.LivingRoom.els, {dir="E", x=BWOARooms.LivingRoom.x2, y=y, z=-4})
    end
end

BWOARooms.LivingRoom.Build = function ()
    BWOARooms.LivingRoom.Init()

    BWOAPrepareTools.DarkenLight(9973, 12631, -4)

    BWOABuildTools.ELS(BWOARooms.LivingRoom.els)
    BWOABuildTools.EmergencyExitW(9973, 12630, -4)
    BWOABuildTools.EmergencyExitW(9973, 12620, -4)

    BWOABuildTools.LampOvalW(9973, 12627, -4)
    BWOABuildTools.LampOvalW(9973, 12623, -4)
    BWOABuildTools.LampOvalE(9980, 12627, -4)
    BWOABuildTools.LampOvalE(9980, 12623, -4)
    BWOABuildTools.LampOvalN(9975, 12618, -4)

    -- tv area
    BWOABuildTools.RemoveObject(9977, 12628, -4, "Couch")
    BWOABuildTools.RemoveObject(9978, 12628, -4, "Couch")
    BWOABuildTools.RemoveObject(9980, 12630, -4, "Television")
    BWOABuildTools.RemoveObject(9980, 12628, -4, "Lights")

    BWOABuildTools.Generic(9977, 12628, -4, "furniture_tables_low_01_19")
    BWOABuildTools.TV(9977, 12628, -4, "appliances_television_01_4")
    BWOABuildTools.LampCustom(9976, 12632, -4, "lighting_indoor_01_58")

    -- gym
    BWOABuildTools.RemoveObject(9975, 12619, -4, "Table")
    BWOABuildTools.RemoveObject(9975, 12620, -4, "Table")
    BWOABuildTools.RemoveObject(9974, 12619, -4, "Chair")
    BWOABuildTools.RemoveObject(9974, 12620, -4, "Chair")
    BWOABuildTools.RemoveObject(9976, 12619, -4, "Chair")
    BWOABuildTools.RemoveObject(9976, 12620, -4, "Chair")
    BWOABuildTools.RemoveObject(9979, 12619, -4, "Table")
    BWOABuildTools.RemoveObject(9979, 12620, -4, "Table")
    BWOABuildTools.RemoveObject(9978, 12619, -4, "Chair")
    BWOABuildTools.RemoveObject(9978, 12620, -4, "Chair")
    BWOABuildTools.RemoveObject(9980, 12619, -4, "Chair")
    BWOABuildTools.RemoveObject(9980, 12620, -4, "Chair")
    BWOABuildTools.RemoveObject(9979, 12622, -4, "Table")
    BWOABuildTools.RemoveObject(9979, 12623, -4, "Table")
    BWOABuildTools.RemoveObject(9978, 12622, -4, "Chair")
    BWOABuildTools.RemoveObject(9978, 12623, -4, "Chair")
    BWOABuildTools.RemoveObject(9980, 12622, -4, "Chair")
    BWOABuildTools.RemoveObject(9980, 12623, -4, "Chair")

    for x = 9974, 9980 do
        BWOABuildTools.Generic(x, 12618, -4, "recreational_sports_01_35")
        BWOABuildTools.Generic(x, 12619, -4, "recreational_sports_01_34")
        BWOABuildTools.Generic(x, 12620, -4, "recreational_sports_01_35")
        BWOABuildTools.Generic(x, 12621, -4, "recreational_sports_01_34")
    end

    BWOABuildTools.Generic(9977, 12619, -4, "recreational_sports_01_41")
    BWOABuildTools.Generic(9977, 12620, -4, "recreational_sports_01_40")

    BWOABuildTools.Generic(9979, 12619, -4, "recreational_sports_01_31")
    BWOABuildTools.Generic(9979, 12620, -4, "recreational_sports_01_30")

    return true
end

BWOARooms.LivingRoom.SetEmitters = function ()
    BWOARooms.LivingRoom.Init()

    BWOASound.AddToObject({x=9973, y=12632, z=-4, sound="AmbientPlumbing"})
    BWOASound.AddToObject({x=9973, y=12618, z=-4, sound="AmbientPlumbing"})
end

BWOARooms.LivingRoom.Prepare = function ()
    BWOARooms.LivingRoom.Init()

    -- tv area
    local tapesSeries = {
        {id="f3e24301-7b24-4daf-ab00-e9502d8dfb22"}, -- Ballincoolin S1.01
        {id="1a5d1e8a-67a0-4526-a216-92641fe98009"}, -- Ballincoolin S1.02
        {id="b2575483-a742-46b3-939a-6f3690ecb8a0"}, -- Ballincoolin S1.03
        {id="0ee453da-77c9-4ce3-a0c8-2d9d981be645"}, -- Ballincoolin S1.04
        {id="8812702d-9d7e-46e3-a8d7-3a580b5fb107"}, -- Ballincoolin S1.05
    }
    
    local mediaRecorder = ZomboidRadio.getInstance():getRecordedMedia()
    local preserve = false
    for _, tapeConf in pairs(tapesSeries) do
        local item = BanditCompatibility.InstanceItem("Base.VHS_Retail")
        local mediaData = mediaRecorder:getMediaData(tapeConf.id)
        item:setRecordedMediaData(mediaData)
        BWOAPrepareTools.AddItemsToContainer(9980, 12631, -4, {item}, "Shelves", preserve)
        preserve = true
    end

    -- gym
    BWOAPrepareTools.AddWorldItem(9975, 12619, -4, "Base.BarBell", {x=0.59, y=0.75, z=0})
    BWOAPrepareTools.AddWorldItem(9974, 12618, -4, "Base.DumbBell", {x=0.94, y=0.46, z=0})
    BWOAPrepareTools.AddWorldItem(9975, 12618, -4, "Base.DumbBell", {x=0.97, y=0.63, z=0})
end


