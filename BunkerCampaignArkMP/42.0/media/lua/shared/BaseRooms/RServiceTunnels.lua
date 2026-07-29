BWOARooms = BWOARooms or {}

BWOARooms.ServiceTunnels = {}

BWOARooms.ServiceTunnels.Init = function ()
    BWOARooms.ServiceTunnels.name = "SERVICE_TUNNELS"
    BWOARooms.ServiceTunnels.x1 = 9944
    BWOARooms.ServiceTunnels.x2 = 9956
    BWOARooms.ServiceTunnels.y1 = 12615
    BWOARooms.ServiceTunnels.y2 = 12623
    BWOARooms.ServiceTunnels.z = -5
    BWOARooms.ServiceTunnels.ambience = ""

    BWOARooms.ServiceTunnels.els = {}
end

BWOARooms.ServiceTunnels.Build = function ()
    BWOARooms.ServiceTunnels.Init()

    -- entrance
    BWOABuildTools.RemoveObject(9975, 12636, -4, "furniture_shelving_01_26")
    BWOABuildTools.RemoveObject(9976, 12636, -4, "furniture_shelving_01_27")
    BWOABuildTools.RemoveObject(9977, 12636, -4, "furniture_shelving_01_26")
    BWOABuildTools.RemoveObject(9978, 12636, -4, "furniture_shelving_01_27")

    local items
    items = {["Base.CarBattery1"] = 3, ["Base.CarBattery2"] = 3, ["Base.CarBattery3"] = 3}
    BWOAPrepareTools.AddItemsToContainer(9973, 12633, -4, items, "Shelves")

    items = {["Base.ModernTire1"] = 4}
    BWOAPrepareTools.AddItemsToContainer(9974, 12633, -4, items, "Shelves")

    items = {["Base.ModernTire2"] = 4}
    BWOAPrepareTools.AddItemsToContainer(9975, 12633, -4, items, "Shelves")

    items = {["Base.ModernTire3"] = 4}
    BWOAPrepareTools.AddItemsToContainer(9976, 12633, -4, items, "Shelves")

    items = {["Base.EngineMaul"] = 4, ["Base.EngineParts"] = 6, ["Base.ModernBrake1"] = 4, ["Base.ModernBrake2"] = 4, ["Base.ModernBrake3"] = 4, ["Base.ModernSuspension1"] = 4, ["Base.ModernSuspension2"] = 4, ["Base.ModernSuspension3"] = 4}
    BWOAPrepareTools.AddItemsToContainer(9977, 12633, -4, items, "Shelves")

    items = {["Base.MufflerPerformance1"] = 1, ["Base.MufflerPerformance2"] = 1, ["Base.MufflerPerformance3"] = 1, ["Base.BigGasTank1"] = 1, ["Base.BigGasTank2"] = 1,["Base.BigGasTank3"] = 1}
    BWOAPrepareTools.AddItemsToContainer(9978, 12633, -4, items, "Shelves")

    -- under control room
    BWOABuildTools.LampBatteryWeak(9960, 12625, -5, "lighting_indoor_02_44")
    BWOABuildTools.Generic(9960, 12624, -5, "industry_02_171")
    BWOABuildTools.Generic(9960, 12623, -5, "industry_02_163")
    BWOABuildTools.Generic(9960, 12622, -5, "industry_02_174")
    BWOABuildTools.Generic(9961, 12622, -5, "industry_02_169")
    BWOABuildTools.Generic(9962, 12622, -5, "industry_02_165")

    -- under generator room
    -- BWOABuildTools.LampBatteryWeak(9953, 12620, -5, "lighting_indoor_02_46")
    -- BWOABuildTools.LampBatteryWeak(9954, 12620, -5, "lighting_indoor_02_46")
    BWOABuildTools.LampBatteryWeak(9953, 12615, -5, "lighting_indoor_02_45")
    -- BWOABuildTools.LampBatteryWeak(9954, 12615, -5, "lighting_indoor_02_45")
    
    -- corridors
    BWOABuildTools.LampBatteryWeak(9969, 12638, -5, "lighting_indoor_02_44")
    BWOABuildTools.LampBatteryWeak(9969, 12634, -5, "lighting_indoor_02_44")
    BWOABuildTools.LampBatteryWeak(9969, 12628, -5, "lighting_indoor_02_44")
    BWOABuildTools.LampBatteryWeak(9962, 12626, -5, "lighting_indoor_02_45")
    BWOABuildTools.LampBatteryWeak(9954, 12623, -5, "lighting_indoor_02_45")
    BWOABuildTools.LampBatteryWeak(9951, 12623, -5, "lighting_indoor_02_44")
    BWOABuildTools.LampBatteryWeak(9962, 12619, -5, "lighting_indoor_02_45")
    BWOABuildTools.LampBatteryWeak(9965, 12608, -5, "lighting_indoor_02_44")

    -- water tanks
    BWOABuildTools.LampBatteryWeak(9951, 12603, -5, "lighting_indoor_03_18")
    BWOABuildTools.LampBatteryWeak(9958, 12603, -5, "lighting_indoor_03_18")
    BWOABuildTools.LampBatteryWeak(9951, 12611, -5, "lighting_indoor_03_18")
    BWOABuildTools.LampBatteryWeak(9958, 12611, -5, "lighting_indoor_03_18")
    BWOABuildTools.LampBatteryWeak(9959, 12600, -7, "lighting_indoor_02_45")
    BWOABuildTools.LampBatteryWeak(9952, 12600, -7, "lighting_indoor_02_45")
    BWOABuildTools.LampBatteryWeak(9959, 12614, -7, "lighting_indoor_02_46")
    BWOABuildTools.LampBatteryWeak(9952, 12614, -7, "lighting_indoor_02_46")

    -- storage room
    BWOABuildTools.LampBatteryWeak(9957, 12617, -5, "lighting_indoor_02_44")

end

BWOARooms.ServiceTunnels.SetEmitters = function ()
    BWOARooms.ServiceTunnels.Init()
    BWOASound.AddToObject({x=9968, y=12631, z=-5, elec=true, sound="AmbientElectricity"})
    BWOASound.AddToObject({x=9956, y=12626, z=-5, elec=true, sound="AmbientElectricity"})
    BWOASound.AddToObject({x=9960, y=12623, z=-5, elec=true, sound="AmbientElectricity"})
end

BWOARooms.ServiceTunnels.SetFlickers = function ()
    BWOARooms.ServiceTunnels.Init()
    BWOALights.AddFlicker({x=9954, y=12615, z=-5})
    BWOALights.AddFlicker({x=9962, y=12626, z=-5})
end

BWOARooms.ServiceTunnels.Prepare = function ()
    BWOARooms.ServiceTunnels.Init()

    local tablets = {["Bandits.NBCTablets"] = 20}
    BWOAPrepareTools.AddItemsToContainer(9950, 12621, -5, tablets, "Locker")

    local leaflet1 = BanditCompatibility.InstanceItem("Bandits.Note")
    leaflet1:setCanBeWrite(false)
    leaflet1:setName(getText("IGUI_Artifact_DeconLeaflet"))
    local md = leaflet1:getModData()
    md.printContent = "leaflet_decon"
    md.BWOA = {}
    md.BWOA.onRead = {}
    md.BWOA.onRead.progressMissionId = 15

    local leaflet2 = BanditCompatibility.InstanceItem("Bandits.Note")
    leaflet2:setCanBeWrite(false)
    leaflet2:setName(getText("IGUI_Artifact_NBCTabletsLeaflet"))
    local md = leaflet2:getModData()
    md.printContent = "leaflet_nbctablets"
    md.BWOA = {}
    md.BWOA.onRead = {}
    md.BWOA.onRead.progressMissionId = 15
    BWOAPrepareTools.AddItemsToContainer(9950, 12621, -5, {leaflet1, leaflet2}, "Locker", true)

    local generatorItems = {["Bandits.EngineCoolant"] = 4, ["Bandits.EngineLubricant"] = 2, ["Base.Charcoal"] = 4}
    BWOAPrepareTools.AddItemsToContainer(9967, 12625, -5, generatorItems, "Locker")

    local spray = BanditCompatibility.InstanceItem("Base.KnapsackSprayer")
    if spray then
        local fluidContainer = spray:getFluidContainer()
        if fluidContainer then
            fluidContainer:Empty()
            fluidContainer:addFluid("Acid", 10)
        end
    end
    BWOAPrepareTools.AddItemsToContainer(9968, 12625, -5, {spray}, "Locker", true)

    for i=1, 4 do
        local can = BanditCompatibility.InstanceItem("Base.JerryCan")
        if can then
            local fluidContainer = can:getFluidContainer()
            if fluidContainer then
                fluidContainer:Empty()
                fluidContainer:addFluid("Acid", 10)
            end
            BWOAPrepareTools.AddItemsToContainer(9968, 12625, -5, {can}, "Locker", true)
        end
    end

    local leaflet3 = BanditCompatibility.InstanceItem("Bandits.Note")
    leaflet3:setCanBeWrite(false)
    leaflet3:setName(getText("IGUI_Artifact_BackpacksprayerLeaflet"))
    local md = leaflet3:getModData()
    md.printContent = "leaflet_backpacksprayer"
    md.BWOA = {}
    md.BWOA.onRead = {}
    md.BWOA.onRead.progressMissionId = 15

    local leaflet4 = BanditCompatibility.InstanceItem("Bandits.Note")
    leaflet4:setCanBeWrite(false)
    leaflet4:setName(getText("IGUI_Artifact_AcidLeaflet"))
    local md = leaflet4:getModData()
    md.printContent = "leaflet_acid"
    md.BWOA = {}
    md.BWOA.onRead = {}
    md.BWOA.onRead.progressMissionId = 15
    BWOAPrepareTools.AddItemsToContainer(9968, 12625, -5, {leaflet3, leaflet4}, "Locker", true)

    -- control room
    local leaflet2 = BanditCompatibility.InstanceItem("Bandits.Note")
    leaflet2:setCanBeWrite(false)
    leaflet2:setName(getText("IGUI_Artifact_NoahCentralComputer"))
    local md = leaflet2:getModData()
    md.printContent = "leaflet_noah"
    md.BWOA = {}
    md.BWOA.onRead = {}
    md.BWOA.onRead.progressMissionId = 15
    BWOAPrepareTools.AddWorldItemSpecial(9962, 12623, -5, leaflet2, {x=0.05, y=0.05, z=0})

    -- vent room
    local leaflet3 = BanditCompatibility.InstanceItem("Bandits.Note")
    leaflet3:setCanBeWrite(false)
    leaflet3:setName(getText("IGUI_Artifact_Ventilation"))
    local md = leaflet3:getModData()
    md.printContent = "leaflet_ventilation"
    md.BWOA = {}
    md.BWOA.onRead = {}
    md.BWOA.onRead.progressMissionId = 15
    BWOAPrepareTools.AddWorldItemSpecial(9966, 12633, -5, leaflet3, {x=0.48, y=0.73, z=0.00, rx=0, ry=0, rz=0})

    -- plant life restoration
    local items1 = {["Base.Fertilizer"] = 10}
    BWOAPrepareTools.AddItemsToContainer(9964, 12618, -5, items1, "Shelves")

    local items2 = {["Base.Fertilizer"] = 10}
    BWOAPrepareTools.AddItemsToContainer(9964, 12617, -5, items2, "Shelves")

    local items3 = {["Base.Sapling"] = 10}
    BWOAPrepareTools.AddItemsToContainer(9961, 12618, -5, items3, "Shelves")

    local items4 = {["Base.Sapling"] = 10}
    BWOAPrepareTools.AddItemsToContainer(9960, 12618, -5, items4, "Shelves")

    local items5 = {["Base.TomatoBagSeed"] = 1, ["Base.PotatoBagSeed2"] = 1, ["Base.SunflowerBagSeed"] = 1, ["Base.ThymeBagSeed"] = 1}
    BWOAPrepareTools.AddItemsToContainer(9958, 12618, -5, items5, "Shelves")

    for x = 9959, 9962 do
        local items = {["Base.Dirtbag"] = 25}
        BWOAPrepareTools.AddItemsToContainer(x, 12615, -5, items, "Shelves")
    end

    local items6 = {["Base.Dirtbag"] = 6}
    BWOAPrepareTools.AddItemsToContainer(9963, 12615, -5, items6, "Shelves")

end

