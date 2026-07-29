BWOARooms = BWOARooms or {}

BWOARooms.Control = {}

BWOARooms.Control.Init = function ()
    BWOARooms.Control.name = "CONTROL_ROOM"
    BWOARooms.Control.x1 = 9959
    BWOARooms.Control.x2 = 9964
    BWOARooms.Control.y1 = 12621
    BWOARooms.Control.y2 = 12630
    BWOARooms.Control.z = -4
    BWOARooms.Control.ambience = ""

    -- BWOARooms.Control.noah = {x=9961, y=12620, z=-4}
    BWOARooms.Control.noah = {x=9964, y=12627, z=-4}

    BWOARooms.Control.vents = {
        {x=9959, y=12626.5, z=-4},
    }

    BWOARooms.Control.els ={
        {dir="W", x=9959, y=12622, z=-4},
        {dir="W", x=9959, y=12623, z=-4},
        {dir="W", x=9959, y=12624, z=-4},
        {dir="XW", x=9959, y=12625, z=-4},
        {dir="W", x=9959, y=12626, z=-4},
        {dir="W", x=9959, y=12629, z=-4},
        {dir="S", x=9961, y=12630, z=-4},
        {dir="S", x=9962, y=12630, z=-4},
        {dir="E", x=9964, y=12629, z=-4},
        {dir="E", x=9964, y=12628, z=-4},
        {dir="E", x=9964, y=12627, z=-4},
        {dir="E", x=9964, y=12624, z=-4},
        {dir="E", x=9964, y=12623, z=-4},
        {dir="E", x=9964, y=12622, z=-4},
        {dir="E", x=9964, y=12621, z=-4},
    }
end

BWOARooms.Control.Build = function ()

    BWOARooms.Control.Init()

    BWOAPrepareTools.DarkenLight(9959, 12624, -4)

    BWOABuildTools.ELS(BWOARooms.Control.els)

    BWOABuildTools.LampOvalW(9959, 12624, -4)
    BWOABuildTools.LampOvalE(9964, 12622, -4)

    BWOABuildTools.LampDeskYellowS(9960, 12630, -4)
    BWOABuildTools.LampDeskYellowS(9964, 12630, -4)

    BWOABuildTools.RemoveObject(9966, 12637, -4, "industry_02_169")
    --[[
    BWOABuildTools.Generic(9960, 12621, -4, "theark_01_2")
    BWOABuildTools.Generic(9961, 12621, -4, "theark_01_4")
    BWOABuildTools.Generic(9962, 12621, -4, "theark_01_3")
    BWOABuildTools.Generic(9963, 12621, -4, "theark_01_2")
    BWOABuildTools.Generic(9964, 12621, -4, "theark_01_3")
    ]]

    BWOABuildTools.RemoveObject(9962, 12624, -4, "location_business_office_generic_01_26")
    BWOABuildTools.RemoveObject(9962, 12625, -4, "location_business_office_generic_01_18")
    BWOABuildTools.RemoveObject(9962, 12626, -4, "location_business_office_generic_01_26")
    BWOABuildTools.RemoveObject(9962, 12627, -4, "location_business_office_generic_01_18")
    BWOABuildTools.RemoveObject(9962, 12629, -4, "location_business_office_generic_01_26")
    BWOABuildTools.RemoveObject(9962, 12630, -4, "location_business_office_generic_01_18")
    BWOABuildTools.RemoveObject(9963, 12626, -4, "location_business_office_generic_01_27")
    BWOABuildTools.RemoveObject(9964, 12626, -4, "location_business_office_generic_01_19")

    BWOABuildTools.RemoveObject(9963, 12624, -4, "furniture_seating_indoor_01_54")
    BWOABuildTools.RemoveObject(9964, 12627, -4, "furniture_seating_indoor_01_55")
    BWOABuildTools.RemoveObject(9963, 12625, -4, "appliances_com_01_10")
    BWOABuildTools.RemoveObject(9964, 12626, -4, "appliances_com_01_8")
    BWOABuildTools.RemoveObject(9963, 12625, -4, "location_business_office_generic_01_44")
    BWOABuildTools.RemoveObject(9963, 12625, -4, "location_business_office_generic_01_44")
    BWOABuildTools.RemoveObject(9964, 12625, -4, "location_business_office_generic_01_45")
    BWOABuildTools.RemoveObject(9963, 12626, -4, "location_business_office_generic_01_42")
    BWOABuildTools.RemoveObject(9964, 12626, -4, "location_business_office_generic_01_43")

    for x = 9960, 9963 do
        for y = 12622, 12625 do
            BWOABuildTools.RemoveObject(x, y, -4, "floors_exterior_street_01_0")
            BWOABuildTools.Floor(x, y, -4, "industry_01_39")
        end
    end

    -- Noah
    local data = {r = 8, g = 4, b = 4, d = 1, battery = true, active = true}
    BWOABuildTools.LampCustom(9964, 12627, -4, "theark_01_20", data)
    BWOABuildTools.Generic(9963, 12627, -4, "appliances_com_01_52")
    BWOABuildTools.Generic(9963, 12626, -4, "security_01_2")
    BWOABuildTools.Generic(9964, 12626, -4, "security_01_2")
    BWOABuildTools.Generic(9964, 12628, -4, "furniture_seating_indoor_01_51")
end

BWOARooms.Control.SetEmitters = function ()
    BWOARooms.Control.Init()
    BWOASound.AddToObject({x=9959.5, y=12621, z=-4, sound="AmbientElectricity"})
    BWOASound.AddToObject({x=9963.5, y=12621, z=-4, sound="AmbientElectricity"})
end

BWOARooms.Control.SetFlickers = function ()
    BWOARooms.Control.Init()
end

BWOARooms.Control.Prepare = function ()
    BWOARooms.Control.Init()

    local report = BanditCompatibility.InstanceItem("Bandits.Note")
    report:setCanBeWrite(false)
    report:setName("Scavenge report")
    local md = report:getModData()
    md.printContent = "scavenge_report_1"
    BWOAPrepareTools.AddItemsToContainer(9959, 12627, -4, {report}, "Cabinet")

    BWOAPrepareTools.AddWorldItem(9959, 12622, -4, "Base.Extinguisher", {x=0.28, y=0.47, z=0.00, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12622, -4, "Base.Extinguisher", {x=0.29, y=0.84, z=0.00, rx=0, ry=0, rz=0})

end


