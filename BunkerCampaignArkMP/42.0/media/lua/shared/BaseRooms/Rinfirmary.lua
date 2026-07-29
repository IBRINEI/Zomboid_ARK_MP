BWOARooms = BWOARooms or {}

BWOARooms.Infirmary = {}

BWOARooms.Infirmary.Init = function ()
    BWOARooms.Infirmary.name = "INFIRMARY"
    BWOARooms.Infirmary.x1 = 9965
    BWOARooms.Infirmary.x2 = 9970
    BWOARooms.Infirmary.y1 = 12621
    BWOARooms.Infirmary.y2 = 12627
    BWOARooms.Infirmary.z = -4
    BWOARooms.Infirmary.ambience = ""

    BWOARooms.Infirmary.els = {}
    for x=BWOARooms.Infirmary.x1, BWOARooms.Infirmary.x2 do
        table.insert(BWOARooms.Infirmary.els, {dir="N", x=x, y=BWOARooms.Infirmary.y1, z=-4})
        table.insert(BWOARooms.Infirmary.els, {dir="S", x=x, y=BWOARooms.Infirmary.y2, z=-4})
    end

    for y=BWOARooms.Infirmary.y1, BWOARooms.Infirmary.y2 do
        table.insert(BWOARooms.Infirmary.els, {dir="W", x=BWOARooms.Infirmary.x1, y=y, z=-4})
        if y ~= BWOARooms.Infirmary.y1 + 3 then
            table.insert(BWOARooms.Infirmary.els, {dir="E", x=BWOARooms.Infirmary.x2, y=y, z=-4})
        end
    end
end

BWOARooms.Infirmary.Build = function ()
    BWOARooms.Infirmary.Init()
    BWOAPrepareTools.DarkenLight(9970, 12625, -4)
    BWOAPrepareTools.DarkenLight(9969, 12627, -4)

    BWOABuildTools.ELS(BWOARooms.Infirmary.els)

    BWOABuildTools.LampOvalW(9965, 12624, -4)
    BWOABuildTools.LampOvalW(9968, 12626, -4)

    BWOABuildTools.RemoveObject(9965, 12624, -4, "Bed")
    BWOABuildTools.RemoveObject(9966, 12624, -4, "Bed")
    BWOABuildTools.RemoveObject(9965, 12625, -4, "Curtain B")
    BWOABuildTools.RemoveObject(9966, 12625, -4, "Curtain C")
    BWOABuildTools.RemoveObject(9967, 12625, -4, "Curtain A")
    BWOABuildTools.RemoveObject(9965, 12627, -4, "Bed")
    BWOABuildTools.RemoveObject(9966, 12627, -4, "Bed")
    BWOABuildTools.RemoveObject(9965, 12626, -4, "Curtain B")
    BWOABuildTools.RemoveObject(9966, 12626, -4, "Curtain C")
    BWOABuildTools.RemoveObject(9967, 12626, -4, "Curtain A")

    BWOABuildTools.RemoveObject(9965, 12622, -4, "Curtain B")
    BWOABuildTools.RemoveObject(9966, 12622, -4, "Curtain C")
    BWOABuildTools.RemoveObject(9967, 12622, -4, "Curtain A")

    BWOABuildTools.Generic(9965, 12623, -4, "location_community_medical_01_22")
    BWOABuildTools.Generic(9966, 12623, -4, "location_community_medical_01_23")
    BWOABuildTools.Generic(9965, 12624, -4, "location_community_medical_01_40")
    BWOABuildTools.Generic(9966, 12624, -4, "location_community_medical_01_42")
    BWOABuildTools.Generic(9967, 12624, -4, "location_community_medical_01_40")

    BWOABuildTools.Generic(9966, 12626, -4, "location_community_medical_01_0")
    BWOABuildTools.Generic(9966, 12625, -4, "location_community_medical_01_1")

    BWOABuildTools.Generic(9965, 12626, -4, "location_community_medical_01_116")
    BWOABuildTools.Generic(9966, 12626, -4, "location_community_medical_01_117")

    BWOABuildTools.LampCustom(9965, 12625, -4, "location_community_medical_01_54")
    BWOABuildTools.Generic(9965, 12625, -4, "location_community_medical_01_161")

    BWOABuildTools.LampCustom(9965, 12626, -4, "location_community_medical_01_54")
    BWOABuildTools.Generic(9965, 12626, -4, "location_community_medical_01_162")

    BWOABuildTools.Generic(9970, 12623, -4, "location_community_medical_01_26")

    

    BWOABuildTools.LampDeskYellowS(9970, 12622, -4)
end

BWOARooms.Infirmary.SetEmitters = function ()
    BWOARooms.Infirmary.Init()
end

BWOARooms.Infirmary.SetFlickers = function ()
    BWOARooms.Infirmary.Init()
    BWOALights.AddFlicker({x=9965, y=12624, z=-4})
end

BWOARooms.Infirmary.Prepare = function ()
    BWOARooms.Infirmary.Init()
    BWOAPrepareTools.AddWorldItem(9969, 12622, -4, "Base.Paperwork", {x=0.5, y=0.5, z=0.35})
    BWOAPrepareTools.AddWorldItem(9969, 12622, -4, "Base.BluePen", {x=0.4, y=0.5, z=0.35})
    BWOAPrepareTools.AddWorldItem(9969, 12622, -4, "Base.Stethoscope", {x=0.8, y=0.2, z=0.35})
    BWOAPrepareTools.AddWorldItem(9970, 12621, -4, "Base.Extinguisher", {x=0.67, y=0.23, z=0.00, rx=0, ry=0, rz=0})

    
    local items
    items = {
        ["Base.Bandage"] = 3, 
        ["Base.AlcoholWipes"] = 2, 
        ["Base.CottonBalls"] = 4, 
        ["Base.Pills"] = 2, 
        ["Base.Disinfectant"] = 1, 
        ["Base.ScissorsBluntMedical"] = 1,
        ["Base.Scalpel"] = 1,
        ["Base.SutureNeedleHolder"] = 1,
        ["Base.Tweezers"] = 1,
        ["Base.Gloves_Surgical"] = 2,
    }
    BWOAPrepareTools.AddItemsToContainer(9969, 12625, -4, items, "Cabinet")

    items = {
        ["Base.AntibioticsBox"] = 2, 
        ["Base.AdhesiveBandageBox"] = 2, 
        ["Base.BandageBox"] = 3,
        ["Base.ColdpackBox"] = 1,
        ["Base.CottonBallsBox"] = 2, 
        ["Base.SutureNeedleBox"] = 2,
        ["Base.TongueDepressorBox"] = 2,
    }
    BWOAPrepareTools.AddItemsToContainer(9969, 12626, -4, items, "Shelves")

    items = {
        ["Base.PillsBeta"] = 5, 
        ["Base.PillsVitamins"] = 6, 
        ["Base.Pills"] = 7,
        ["Base.PillsSleepingTablets"] = 3,
        ["Bandits.PillsPotassiumIodine"] = 4,
        ["Bandits.PillsPentoxifylline"] = 5,
        ["Bandits.PillsNikethamide"] = 3,
        ["Base.Gloves_Surgical"] = 24, 
        ["Base.PillsAntiDep"] = 2, 
        ["Base.Hat_SurgicalCap"] = 24, 
        ["Base.Hat_SurgicalMask"] = 24, 
        ["Base.Shoes_FlipFlop"] = 3, 
        ["Base.Pillow"] = 3, 
    }
    BWOAPrepareTools.AddItemsToContainer(9970, 12626, -4, items, "Shelves")

    local medical = BanditCompatibility.InstanceItem("Bandits.Note")
    medical:setCanBeWrite(false)
    medical:setName(getText("IGUI_Artifact_MedicalReport"))
    local md = medical:getModData()
    md.printContent = "medical"
    BWOAPrepareTools.AddWorldItemSpecial(9969, 12622, -4, medical, {x=0.6, y=0.6, z=0.35})

    local leafletPotassiumIodine = BanditCompatibility.InstanceItem("Bandits.Note")
    leafletPotassiumIodine:setCanBeWrite(false)
    leafletPotassiumIodine:setName(getText("IGUI_Artifact_IodineLeaflet"))
    local md = leafletPotassiumIodine:getModData()
    md.printContent = "leaflet_potassium_iodine"
    md.BWOA = {}
    md.BWOA.onRead = {}
    md.BWOA.onRead.progressMissionId = 15

    BWOAPrepareTools.AddItemsToContainer(9970, 12626, -4, {leafletPotassiumIodine}, "Shelves", true)

    local leafletNikethamide = BanditCompatibility.InstanceItem("Bandits.Note")
    leafletNikethamide:setCanBeWrite(false)
    leafletNikethamide:setName(getText("IGUI_Artifact_NikethamideLeaflet"))
    local md = leafletNikethamide:getModData()
    md.printContent = "leaflet_nikethamide"
    md.BWOA = {}
    md.BWOA.onRead = {}
    md.BWOA.onRead.progressMissionId = 15
    BWOAPrepareTools.AddItemsToContainer(9970, 12626, -4, {leafletNikethamide}, "Shelves", true)

    local leafletPentoxifylline = BanditCompatibility.InstanceItem("Bandits.Note")
    leafletPentoxifylline:setCanBeWrite(false)
    leafletPentoxifylline:setName(getText("IGUI_Artifact_PentoxifyllineLeaflet"))
    local md = leafletPentoxifylline:getModData()
    md.printContent = "leaflet_pentoxifylline"
    md.BWOA = {}
    md.BWOA.onRead = {}
    md.BWOA.onRead.progressMissionId = 15
    BWOAPrepareTools.AddItemsToContainer(9970, 12626, -4, {leafletPentoxifylline}, "Shelves", true)

    --[[
    items = {
        ["Base.Book_Medical"] = 4, 
        ["Base.Eraser"] = 1, 
        ["Base.Pencil"] = 1, 
    }
    BWOAPrepareTools.AddItemsToContainer(9965, 12625, -4, items, "Desk")
    ]]
    
end


