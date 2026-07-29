BWOARooms = BWOARooms or {}

BWOARooms.Armory = {}

BWOARooms.Armory.Init = function ()
    BWOARooms.Armory.name = "ARMORY"
    BWOARooms.Armory.x1 = 9973
    BWOARooms.Armory.x2 = 9978
    BWOARooms.Armory.y1 = 12614
    BWOARooms.Armory.y2 = 12617
    BWOARooms.Armory.z = -4
    BWOARooms.Armory.ambience = ""

    BWOARooms.Armory.vents = {
        {x=9973, y=12616.5, z=-4},
    }

    BWOARooms.Armory.els = {}
    for x=BWOARooms.Armory.x1, BWOARooms.Armory.x2 do
        table.insert(BWOARooms.Armory.els, {dir="N", x=x, y=BWOARooms.Armory.y1, z=-4})
        table.insert(BWOARooms.Armory.els, {dir="S", x=x, y=BWOARooms.Armory.y2, z=-4})
    end

    for y=BWOARooms.Armory.y1, BWOARooms.Armory.y2 do
        if y ~= 12615 then
            table.insert(BWOARooms.Armory.els, {dir="W", x=BWOARooms.Armory.x1, y=y, z=-4})
        end
        table.insert(BWOARooms.Armory.els, {dir="E", x=BWOARooms.Armory.x2, y=y, z=-4})
    end
    
end

BWOARooms.Armory.Build = function ()
    BWOARooms.Armory.Init()
    BWOAPrepareTools.DarkenLight(9973, 12614, -4)

    BWOABuildTools.ELS(BWOARooms.Armory.els)

    BWOABuildTools.EmergencyExitW(9973, 12615, -4)

    BWOABuildTools.LampOvalN(9976, 12614, -4)
    BWOABuildTools.LampOvalS(9976, 12617, -4)

end

BWOARooms.Armory.SetEmitters = function ()
    BWOARooms.Armory.Init()
end

BWOARooms.Armory.SetFlickers = function ()
    BWOARooms.Armory.Init()

    BWOALights.AddFlicker({x=9976, y=12614, z=-4})
    BWOALights.AddFlicker({x=9976, y=12617, z=-4})
end

BWOARooms.Armory.Prepare = function ()
    BWOARooms.Armory.Init()

    BWOAPrepareTools.AddWorldItem(9973, 12614, -4, "Base.Shotgun", {x=0.49, y=0.26, z=0.21, rx=21, ry=90, rz=93})
    BWOAPrepareTools.AddWorldItem(9973, 12614, -4, "Base.ShotgunShellsCarton", {x=0.68, y=0.29, z=0.00, rx=0, ry=0, rz=0})

    local items
    items = {["Base.HazmatSuitCamo"] = 7, ["Base.Hat_GasMask"] = 6, ["Bandits.GeigerCounter"] = 2, ["Base.GasmaskFilter"] = 4}
    BWOAPrepareTools.AddItemsToContainer(9974, 12614, -4, items, "Locker")

    local leaflet = BanditCompatibility.InstanceItem("Bandits.Note")
    leaflet:setCanBeWrite(false)
    leaflet:setName(getText("IGUI_Artifact_LevelCHazmatSuit"))
    local md = leaflet:getModData()
    md.printContent = "leaflet_hazmat"
    md.BWOA = {}
    md.BWOA.onRead = {}
    md.BWOA.onRead.progressMissionId = 15

    BWOAPrepareTools.AddItemsToContainer(9974, 12614, -4, {leaflet}, "Locker", true)

    items = {["Base.Pistol"] = 2, ["Base.9mmClip"] = 4, ["Base.Bullets9mmBox"] = 5}
    BWOAPrepareTools.AddItemsToContainer(9975, 12614, -4, items, "Locker")

    items = {["Base.Pistol2"] = 1, ["Base.45Clip"] = 2, ["Base.Bullets45Box"] = 7 }
    BWOAPrepareTools.AddItemsToContainer(9976, 12614, -4, items, "Locker")

    items = {["Base.AssaultRifle2"] = 2, ["Base.M14Clip"] = 6, ["Base.308Box"] = 3 }
    BWOAPrepareTools.AddItemsToContainer(9977, 12614, -4, items, "Locker")

    BWOAPrepareTools.AddWorldItem(9978, 12614, -4, "Base.Bag_ALICEpack", {x=0.5, y=0.72, z=0.27})
    BWOAPrepareTools.AddWorldItem(9978, 12615, -4, "Base.Bag_ALICEpack", {x=0.5, y=0.72, z=0.27})

    BWOAPrepareTools.AddWorldItem(9978, 12616, -4, "Base.HuntingKnife", {x=0.63, y=0.21, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9978, 12616, -4, "Base.HuntingKnife", {x=0.73, y=0.39, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9978, 12616, -4, "Base.HuntingKnife", {x=0.69, y=0.56, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9978, 12616, -4, "Base.HuntingKnife", {x=0.69, y=0.78, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9978, 12616, -4, "Base.Machete", {x=0.2, y=0.52, z=0.27, rx=0, ry=0, rx=0, ry=0, rz=90})
    BWOAPrepareTools.AddWorldItem(9978, 12616, -4, "Base.Machete", {x=0.38, y=0.53, z=0.27, rx=0, ry=0, ry=0, rx=0, rz=90})

    BWOAPrepareTools.AddWorldItem(9978, 12617, -4, "Base.BatteryBox", {x=0.74, y=0.26, z=0.27})
    BWOAPrepareTools.AddWorldItem(9978, 12617, -4, "Base.WristWatch_Left_ClassicMilitary", {x=0.23, y=0.15, z=0.27})
    BWOAPrepareTools.AddWorldItem(9978, 12617, -4, "Base.WristWatch_Left_ClassicMilitary", {x=0.24, y=0.32, z=0.27})
    BWOAPrepareTools.AddWorldItem(9978, 12617, -4, "Base.HandTorch", {x=0.3, y=0.55, z=0.27})
    BWOAPrepareTools.AddWorldItem(9978, 12617, -4, "Base.HandTorch", {x=0.3, y=0.7, z=0.27})
    BWOAPrepareTools.AddWorldItem(9978, 12617, -4, "Base.FlashLight_AngleHead", {x=0.73, y=0.61, z=0.27})
    BWOAPrepareTools.AddWorldItem(9978, 12617, -4, "Base.FlashLight_AngleHead", {x=0.73, y=0.27, z=0.27})

    items = {["Base.Bag_ALICE_BeltSus_Camo"] = 4, ["Base.Vest_BulletArmy"] = 6, ["Base.Hat_Army"] = 6, ["Base.HolsterSimple_Brown"] = 6 }
    BWOAPrepareTools.AddItemsToContainer(9974, 12617, -4, items, "Locker")

    items = {["Base.Shoes_ArmyBoots"] = 6, ["Base.Gloves_LeatherGlovesBlack"] = 6, ["Base.Hat_BalaclavaFull"] = 6 }
    BWOAPrepareTools.AddItemsToContainer(9975, 12617, -4, items, "Locker")

    items = {["Base.Trousers_CamoGreen"] = 4, ["Base.Shirt_CamoGreen"] = 6, ["Base.Tshirt_CamoGreen"] = 6, ["Base.Jacket_ArmyCamoGreen"] = 6 }
    BWOAPrepareTools.AddItemsToContainer(9976, 12617, -4, items, "Locker")

end


