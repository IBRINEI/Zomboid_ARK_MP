BWOARooms = BWOARooms or {}

BWOARooms.Bedroom = {}

BWOARooms.Bedroom.Init = function ()
    BWOARooms.Bedroom.name = "BEDROOM"
    BWOARooms.Bedroom.x1 = 9944
    BWOARooms.Bedroom.x2 = 9956
    BWOARooms.Bedroom.y1 = 12636
    BWOARooms.Bedroom.y2 = 12642
    BWOARooms.Bedroom.z = -4
    BWOARooms.Bedroom.ambience = ""

    BWOARooms.Bedroom.vents = {
        {x=9944, y=12636.5, z=-4},
    }

    BWOARooms.Bedroom.els = {}
    for x=9944, 9956 do
        table.insert(BWOARooms.Bedroom.els, {dir="S", x=x, y=12642, z=-4})
        table.insert(BWOARooms.Bedroom.els, {dir="N", x=x, y=12636, z=-4})
    end

    for y=12636, 12642 do
        table.insert(BWOARooms.Bedroom.els, {dir="W", x=9944, y=y, z=-4})
        if y ~= 12639 then
            table.insert(BWOARooms.Bedroom.els, {dir="E", x=9956, y=y, z=-4})
        end
    end
end

BWOARooms.Bedroom.Build = function ()

    BWOARooms.Bedroom.Init()

    BWOAPrepareTools.DarkenLight(9956, 12640, -4)

    BWOABuildTools.ELS(BWOARooms.Bedroom.els)

    BWOABuildTools.LampOvalN(9945, 12636, -4)
    BWOABuildTools.LampOvalN(9952, 12636, -4)
    BWOABuildTools.LampOvalS(9945, 12642, -4)
    BWOABuildTools.LampOvalS(9952, 12642, -4)

    for x=BWOARooms.Bedroom.x1, BWOARooms.Bedroom.x2 do
        for y=BWOARooms.Bedroom.y1, BWOARooms.Bedroom.y2 do
            BWOABuildTools.RemoveObject(x, y, -4, "Beds")
        end
    end

    BWOABuildTools.VentN(9944, 12636, -4)

    for x = 9947, 9955, 2 do
        BWOABuildTools.Bed(x, 12636, -4, "furniture_bedding_01_65")
        BWOABuildTools.Bed(x, 12637, -4, "furniture_bedding_01_64")

        BWOABuildTools.Bed(x, 12641, -4, "furniture_bedding_01_65")
        BWOABuildTools.Bed(x, 12642, -4, "furniture_bedding_01_64")
    end

    for x = 9948, 9954, 2 do
        BWOABuildTools.Generic(x, 12636, -4, "furniture_storage_01_33")
        BWOABuildTools.Generic(x, 12642, -4, "furniture_storage_01_35")
    end
    -- BWOABuildTools.Generic(9956, 12636, -4, "vegetation_indoor_01_1")

    BWOABuildTools.Generic(9946, 12636, -4, "walls_decoration_02_23")
    -- BWOABuildTools.Generic(9948, 12636, -4, "walls_decoration_02_70")
    -- BWOABuildTools.Generic(9950, 12636, -4, "walls_decoration_02_67")
    -- BWOABuildTools.Generic(9954, 12636, -4, "walls_decoration_02_86")
    BWOABuildTools.Generic(9956, 12636, -4, "walls_decoration_01_48")

end

BWOARooms.Bedroom.SetEmitters = function ()
    BWOARooms.Bedroom.Init()
    -- BWOASound.AddToObject({x=9948, y=12605, z=-4, sound="AmbientWaterDrops"})
end

BWOARooms.Bedroom.SetFlickers = function ()
    BWOARooms.Bedroom.Init()
    BWOALights.AddFlicker({x=9945, y=12636, z=-4})
end

BWOARooms.Bedroom.Prepare = function ()
    BWOARooms.Bedroom.Init()

    -- lockers
    local items

    items = {["Base.Boilersuit_Flying"] = 1, ["Base.Briefs_White"] = 6, ["Base.Vest_DefaultTEXTURE"] = 4, ["Base.Tshirt_WhiteTINT"] = 5, ["Base.Shoes_Black"] = 1}
    BWOAPrepareTools.AddItemsToContainer(9944, 12637, -4, items, "Locker")

    items = {["Base.Boilersuit_Flying"] = 1, ["Base.LongJohns"] = 1, ["Base.Shirt_Denim"] = 1, ["Base.Briefs_White"] = 6, ["Base.Vest_DefaultTEXTURE"] = 4, ["Base.Tshirt_WhiteTINT"] = 5, ["Base.Shoes_Black"] = 1}
    BWOAPrepareTools.AddItemsToContainer(9944, 12638, -4, items, "Locker")

    items = {["Base.Underpants_White"] = 6, ["Base.Vest_DefaultTEXTURE"] = 4, ["Base.Tshirt_WhiteTINT"] = 4, ["Base.Tshirt_WhiteLongSleeveTINT"] = 2, ["Base.Shoes_Black"] = 1, ["Base.Belt2"] = 1}
    BWOAPrepareTools.AddItemsToContainer(9944, 12639, -4, items, "Locker")

    items = {["Base.Boilersuit_Flying"] = 1, ["Base.LongJohns"] = 1, ["Base.Shirt_Denim"] = 1, ["Base.Scarf_StripeBlackWhite"] = 2, ["Base.Tshirt_WhiteLongSleeveTINT"] = 2, ["Base.Briefs_White"] = 6, ["Base.Vest_DefaultTEXTURE"] = 3, ["Base.Tshirt_WhiteTINT"] = 2, ["Base.Shoes_Black"] = 1}
    BWOAPrepareTools.AddItemsToContainer(9944, 12640, -4, items, "Locker")

    items = {["Base.Boilersuit_Flying"] = 1, ["Base.Jumper_DiamondPatternTINT"] = 2, ["Base.Briefs_White"] = 6, ["Base.Vest_DefaultTEXTURE"] = 2, ["Base.Tshirt_WhiteTINT"] = 4, ["Base.Shoes_Black"] = 1, ["Base.Belt2"] = 1}
    BWOAPrepareTools.AddItemsToContainer(9944, 12641, -4, items, "Locker")

    -- pillows
    for _, y in pairs({12636, 12642}) do
        for _, x in pairs({9947, 9949, 9951, 9952, 9955}) do 
            BWOAPrepareTools.AddWorldItem(x, y, -4, "Base.Pillow", {x=0.5, y=0.5, z=0.3})
        end
    end

    -- bed magazines
    BWOAPrepareTools.AddWorldItem(9947, 12637, -4, "Base.MagazineWordsearch", {x=0.5, y=0.5, z=0.3})
    BWOAPrepareTools.AddWorldItem(9947, 12637, -4, "Base.Pencil", {x=0.5, y=0.5, z=0.3})

    BWOAPrepareTools.AddWorldItem(9947, 12637, -4, "Base.SheetPaper2", {x=0.5, y=0.5, z=0.3})
    BWOAPrepareTools.AddWorldItem(9947, 12637, -4, "Base.Crayons", {x=0.5, y=0.5, z=0.3})

    BWOAPrepareTools.AddWorldItem(9951, 12637, -4, "Base.HottieZ_New", {x=0.5, y=0.5, z=0.3})

    BWOAPrepareTools.AddWorldItem(9951, 12637, -4, "Base.Notebook", {x=0.5, y=0.5, z=0.3})
    BWOAPrepareTools.AddWorldItem(9951, 12637, -4, "Base.Pencil", {x=0.5, y=0.5, z=0.3})

    BWOAPrepareTools.AddWorldItem(9955, 12637, -4, "Base.Magazine", {x=0.5, y=0.5, z=0.3})
    BWOAPrepareTools.AddWorldItem(9955, 12637, -4, "Base.Magazine", {x=0.5, y=0.5, z=0.3})

    -- table items
    BWOAPrepareTools.AddWorldItem(9948, 12636, -4, "Base.MugWhite", {x=0.4, y=0.7, z=0.36})
    BWOAPrepareTools.AddWorldItem(9948, 12636, -4, "Base.CaseyPic", {x=0.5, y=0.4, z=0.36, rz=0})

    BWOAPrepareTools.AddWorldItem(9950, 12636, -4, "Base.ChessWhite", {x=0.4, y=0.4, z=0.36})
    BWOAPrepareTools.AddWorldItem(9950, 12636, -4, "Base.ChessBlack", {x=0.6, y=0.6, z=0.36})

    BWOAPrepareTools.AddWorldItem(9952, 12636, -4, "Base.Book", {x=0.5, y=0.6, z=0.36})

    BWOAPrepareTools.AddWorldItem(9954, 12636, -4, "Base.MugWhite", {x=0.4, y=0.4, z=0.36})
    BWOAPrepareTools.AddWorldItem(9954, 12636, -4, "Base.Pen", {x=0.6, y=0.6, z=0.36})
    BWOAPrepareTools.AddWorldItem(9954, 12636, -4, "Base.MagazineWordsearch", {x=0.5, y=0.5, z=0.36})

    -- BWOAPrepareTools.AddWorldItem(9956, 12636, -4, "Base.Cube", {x=0.62, y=0.55, z=0.36})
    -- BWOAPrepareTools.AddWorldItem(9956, 12636, -4, "Base.Cube", {x=0.74, y=0.59, z=0.36})
    -- BWOAPrepareTools.AddWorldItem(9956, 12636, -4, "Base.Pills", {x=0.66, y=0.64, z=0.36})

    
    BWOAPrepareTools.AddWorldItem(9948, 12642, -4, "Base.MugWhite", {x=0.4, y=0.7, z=0.36})
    BWOAPrepareTools.AddWorldItem(9948, 12642, -4, "Base.PillsSleepingTablets", {x=0.5, y=0.4, z=0.36, rz=0})

    BWOAPrepareTools.AddWorldItem(9950, 12642, -4, "Base.Glasses_Normal", {x=0.4, y=0.4, z=0.36})
    BWOAPrepareTools.AddWorldItem(9950, 12642, -4, "Base.Book", {x=0.6, y=0.6, z=0.36})

    BWOAPrepareTools.AddWorldItem(9952, 12642, -4, "Base.ToyCar", {x=0.4, y=0.5, z=0.36, rz = 60})
    BWOAPrepareTools.AddWorldItem(9952, 12642, -4, "Base.ToyCar", {x=0.5, y=0.5, z=0.36, rz = 60})
    BWOAPrepareTools.AddWorldItem(9952, 12642, -4, "Base.ToyCar", {x=0.6, y=0.5, z=0.36, rz = 60})

    BWOAPrepareTools.AddWorldItem(9954, 12642, -4, "Base.Pencil", {x=0.4, y=0.4, z=0.36})
    BWOAPrepareTools.AddWorldItem(9954, 12642, -4, "Base.MagazineWordsearch", {x=0.6, y=0.6, z=0.36})
    BWOAPrepareTools.AddWorldItem(9954, 12642, -4, "Base.MagazineWordsearch", {x=0.5, y=0.5, z=0.36})

    -- BWOAPrepareTools.AddWorldItem(9956, 12642, -4, "Base.Pencil", {x=0.62, y=0.55, z=0.3})
    -- BWOAPrepareTools.AddWorldItem(9956, 12642, -4, "Base.TissueBox", {x=0.74, y=0.59, z=0.3})
    -- BWOAPrepareTools.AddWorldItem(9956, 12642, -4, "Base.Pills", {x=0.66, y=0.64, z=0.3})

    -- drawers

    local healthEffectsRadiation = BanditCompatibility.InstanceItem("Bandits.Book2")
    healthEffectsRadiation:setCanBeWrite(false)
    healthEffectsRadiation:setName(getText("IGUI_Artifact_EffectsRadiation"))
    local md = healthEffectsRadiation:getModData()
    md.printContent = "health_effects_radiation"
    md.BWOA = {}
    md.BWOA.onRead = {}
    md.BWOA.onRead.progressMissionId = 15

    local x = BanditUtils.Choice({9948, 9950, 9952, 9954, 9956})
    local y = BanditUtils.Choice({12642, 12636})
    BWOAPrepareTools.AddItemsToContainer(9948, 12642, -4, {healthEffectsRadiation}, "Drawers")

    -- others
    BWOAPrepareTools.AddWorldItem(9945, 12636, -4, "Base.GuitarAcoustic", {x=0.5, y=0.27, z=0.18, rx=0, ry=295, rz=90})

end


