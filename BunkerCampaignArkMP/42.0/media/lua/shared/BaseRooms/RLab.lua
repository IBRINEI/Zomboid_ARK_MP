BWOARooms = BWOARooms or {}

BWOARooms.Lab = {}

BWOARooms.Lab.Init = function ()
    BWOARooms.Lab.name = "LABORATORY"
    BWOARooms.Lab.x1 = 9959
    BWOARooms.Lab.x2 = 9965
    BWOARooms.Lab.y1 = 12636
    BWOARooms.Lab.y2 = 12640
    BWOARooms.Lab.z = -4
    BWOARooms.Lab.ambience = ""

    BWOARooms.Lab.vents = {
        {x=9963, y=12636.5, z=-4},
    }

    BWOARooms.Lab.els = {}
    for x=BWOARooms.Lab.x1, BWOARooms.Lab.x2 - 1 do
        table.insert(BWOARooms.Lab.els, {dir="N", x=x, y=BWOARooms.Lab.y1, z=-4})
        if x ~= 9962 then
            table.insert(BWOARooms.Lab.els, {dir="S", x=x, y=BWOARooms.Lab.y2, z=-4})
        end
    end

    for y=BWOARooms.Lab.y1, BWOARooms.Lab.y2 - 1 do
        table.insert(BWOARooms.Lab.els, {dir="W", x=BWOARooms.Lab.x1, y=y, z=-4})
        table.insert(BWOARooms.Lab.els, {dir="E", x=BWOARooms.Lab.x2, y=y, z=-4})
    end
end

BWOARooms.Lab.Build = function ()

    BWOARooms.Lab.Init()

    BWOAPrepareTools.DarkenLight(9963, 12640, -4)

    BWOABuildTools.ELS(BWOARooms.Lab.els)

    BWOABuildTools.LampOvalN(9960, 12636, -4)
    BWOABuildTools.LampOvalN(9964, 12636, -4)

    BWOABuildTools.RemoveObject(9959, 12637, -4, "Contraption")
    BWOABuildTools.RemoveObject(9960, 12637, -4, "Contraption")
    BWOABuildTools.RemoveObject(9959, 12639, -4, "Contraption")
    BWOABuildTools.RemoveObject(9960, 12639, -4, "Contraption")
    BWOABuildTools.RemoveObject(9962, 12638, -4, "Mat")
    BWOABuildTools.RemoveObject(9962, 12639, -4, "Mat")
    BWOABuildTools.RemoveObject(9962, 12636, -4, "Sink")
    BWOABuildTools.RemoveObject(9964, 12636, -4, "Hamster Wheel")
    BWOABuildTools.RemoveObject(9965, 12636, -4, "Hamster Wheel")
    BWOABuildTools.RemoveObject(9964, 12638, -4, "Hamster Wheel")
    BWOABuildTools.RemoveObject(9965, 12638, -4, "Hamster Wheel")
    BWOABuildTools.RemoveObject(9964, 12640, -4, "Hamster Wheel")
    BWOABuildTools.RemoveObject(9965, 12640, -4, "Hamster Wheel")

    -- closets
    BWOABuildTools.Generic(9959, 12636, -4, "location_community_medical_01_153")
    BWOABuildTools.Generic(9959, 12637, -4, "location_community_medical_01_152")
    BWOABuildTools.Generic(9959, 12638, -4, "location_community_medical_01_103")
    BWOABuildTools.Generic(9959, 12639, -4, "location_community_medical_01_103")
    BWOABuildTools.Generic(9959, 12640, -4,  "location_community_medical_01_103")


    -- desk
    BWOABuildTools.Mannequin(9960, 12636, -4, "MannequinSkeleton01", IsoDirections.S)
    BWOABuildTools.Generic(9961, 12636, -4, "location_community_medical_01_107")
    BWOABuildTools.Generic(9962, 12636, -4, "location_community_medical_01_108")
    BWOABuildTools.Generic(9963, 12636, -4, "location_community_medical_01_108")
    BWOABuildTools.Generic(9964, 12636, -4, "location_community_medical_01_109")

    BWOABuildTools.Generic(9961, 12636, -4, "location_community_medical_01_11") -- poster
    BWOABuildTools.Generic(9961, 12636, -4, "location_community_medical_01_136") -- microscope
    BWOABuildTools.Generic(9963, 12636, -4, "appliances_com_01_72") -- computer
    BWOABuildTools.Generic(9963, 12637, -4, "furniture_seating_indoor_01_51") -- chair

    -- desk 2
    BWOABuildTools.Generic(9963, 12639, -4, "location_community_medical_01_107")
    BWOABuildTools.Generic(9964, 12639, -4, "location_community_medical_01_108")
    BWOABuildTools.Generic(9965, 12639, -4, "location_community_medical_01_109")
    BWOABuildTools.LampDeskYellowN(9963, 12639, -4)
    BWOABuildTools.Generic(9964, 12639, -4, "location_community_medical_01_136") -- microscope
    BWOABuildTools.Generic(9965, 12639, -4, "fixtures_sinks_01_17")
    BWOABuildTools.Generic(9964, 12640, -4, "location_community_medical_01_10") -- processing table


    BWOABuildTools.Generic(9961, 12639, -4, "location_community_medical_01_78") -- processing table
    BWOABuildTools.Generic(9961, 12638, -4, "location_community_medical_01_79") -- processing table

    -- metal cabinet
    BWOABuildTools.Generic(9965, 12636, -4, "furniture_storage_02_0")
    
    BWOABuildTools.VentW(9963, 12636, -4) --vent
end

BWOARooms.Lab.SetEmitters = function ()
    BWOARooms.Lab.Init()
end

BWOARooms.Lab.Prepare = function ()
    BWOARooms.Lab.Init()

    BWOAPrepareTools.AddWorldItem(9961, 12636, -4, "Base.Hominid_Skull", {x=0.91, y=0.34, z=0.38, rx=0, ry=0, rz=85})
    BWOAPrepareTools.AddWorldItem(9961, 12636, -4, "Base.Specimen_Beetles", {x=0.95, y=0.70, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9962, 12636, -4, "Base.Specimen_Butterflies", {x=0.29, y=0.52, z=0.38, rx=0, ry=0, rz=90})
    BWOAPrepareTools.AddWorldItem(9962, 12636, -4, "Base.Specimen_Insects", {x=0.33, y=0.83, z=0.38, rx=0, ry=0, rz=265})
    BWOAPrepareTools.AddWorldItem(9962, 12636, -4, "Base.Specimen_Brain", {x=0.16, y=0.24, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9962, 12636, -4, "Base.Specimen_Brain", {x=0.31, y=0.22, z=0.38, rx=0, ry=0, rz=70})
    BWOAPrepareTools.AddWorldItem(9962, 12636, -4, "Base.Specimen_Brain", {x=0.46, y=0.20, z=0.38, rx=0, ry=0, rz=70})
    BWOAPrepareTools.AddWorldItem(9962, 12636, -4, "Base.Specimen_Centipedes", {x=0.56, y=0.38, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9962, 12636, -4, "Base.Specimen_FetalCalf", {x=0.62, y=0.25, z=0.38, rx=0, ry=0, rz=35})
    BWOAPrepareTools.AddWorldItem(9962, 12636, -4, "Base.Specimen_MonkeyHead", {x=0.77, y=0.20, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9962, 12636, -4, "Base.Specimen_Octopus", {x=0.77, y=0.36, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9962, 12636, -4, "Base.Specimen_Tapeworm", {x=0.91, y=0.27, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9962, 12636, -4, "Base.MagnifyingGlass", {x=0.66, y=0.68, z=0.38, rx=0, ry=0, rz=150})
    BWOAPrepareTools.AddWorldItem(9964, 12636, -4, "Base.MugSpiffo", {x=0.08, y=0.73, z=0.38, rx=0, ry=0, rz=35})
    BWOAPrepareTools.AddWorldItem(9964, 12636, -4, "Base.PencilCase", {x=0.14, y=0.39, z=0.38, rx=0, ry=0, rz=30})
    BWOAPrepareTools.AddWorldItem(9964, 12636, -4, "Base.Notebook", {x=0.32, y=0.71, z=0.38, rx=0, ry=0, rz=5})
    BWOAPrepareTools.AddWorldItem(9964, 12636, -4, "Base.Pencil", {x=0.39, y=0.58, z=0.38, rx=0, ry=0, rz=70})
    BWOAPrepareTools.AddWorldItem(9964, 12636, -4, "Base.BookFirstAid4", {x=0.44, y=0.31, z=0.38, rx=0, ry=0, rz=60})
    BWOAPrepareTools.AddWorldItem(9964, 12636, -4, "Base.Eraser", {x=0.26, y=0.46, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9964, 12636, -4, "Base.Calculator", {x=0.62, y=0.62, z=0.38, rx=0, ry=0, rz=85})

    BWOAPrepareTools.AddWorldItem(9961, 12638, -4, "Base.Hominid_Skull_Partial", {x=0.45, y=0.55, z=0.33, rx=0, ry=0, rz=50})
    BWOAPrepareTools.AddWorldItem(9961, 12638, -4, "Base.BoneBead_Large", {x=0.36, y=0.67, z=0.33, rx=0, ry=0, rz=40})
    BWOAPrepareTools.AddWorldItem(9961, 12638, -4, "Base.BoneBead_Large", {x=0.26, y=0.59, z=0.33, rx=0, ry=0, rz=70})
    BWOAPrepareTools.AddWorldItem(9961, 12638, -4, "Base.Hominid_Skull_Fragment", {x=0.57, y=0.43, z=0.33, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9961, 12638, -4, "Base.SharpBoneFragment", {x=0.66, y=0.69, z=0.33, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9961, 12638, -4, "Base.SharpBoneFragment", {x=0.45, y=0.39, z=0.33, rx=0, ry=0, rz=65})
    BWOAPrepareTools.AddWorldItem(9961, 12638, -4, "Base.AnimalBone", {x=0.30, y=0.76, z=0.33, rx=0, ry=0, rz=45})

    BWOAPrepareTools.AddWorldItem(9963, 12639, -4, "Base.Stethoscope", {x=0.26, y=0.43, z=0.38, rx=0, ry=0, rz=30})
    BWOAPrepareTools.AddWorldItem(9965, 12639, -4, "Base.Soap2", {x=0.84, y=0.32, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12639, -4, "Base.Disinfectant", {x=0.78, y=0.16, z=0.38, rx=0, ry=0, rz=350})

    items = {
        ["Base.JacketLong_Doctor"] = 4, 
        ["Base.Gloves_Surgical"] = 40, 
        ["Base.Hat_SurgicalCap"] = 14, 
        ["Base.Hat_SurgicalMask"] = 46, 
    }
    BWOAPrepareTools.AddItemsToContainer(9965, 12636, -4, items, "Locker")

    items = {
        ["Base.ScissorsBluntMedical"] = 4, 
        ["Base.Gloves_Surgical"] = 4, 
        ["Base.Hat_SurgicalCap"] = 1, 
        ["Base.Hat_SurgicalMask"] = 5, 
        ["Base.Disinfectant"] = 2, 
        ["Base.Scalpel"] = 3, 
        ["Base.SmallSaw"] = 1, 
        ["Base.Book_Medical"] = 4, 
    }
    BWOAPrepareTools.AddItemsToContainer(9963, 12639, -4, items, "Desk")
end


