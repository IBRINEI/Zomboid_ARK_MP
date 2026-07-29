BWOARooms = BWOARooms or {}

BWOARooms.Messhall = {}

BWOARooms.Messhall.Init = function ()
    BWOARooms.Messhall.name = "MESSHALL"
    BWOARooms.Messhall.x1 = 9959
    BWOARooms.Messhall.x2 = 9970
    BWOARooms.Messhall.y1 = 12610
    BWOARooms.Messhall.y2 = 12620
    BWOARooms.Messhall.z = -4
    BWOARooms.Messhall.ambience = ""

    BWOARooms.Messhall.vents = {
        {x=9959, y=12614.5, z=-4},
    }

    BWOARooms.Messhall.els = {}
    for x=BWOARooms.Messhall.x1, BWOARooms.Messhall.x2 do
        table.insert(BWOARooms.Messhall.els, {dir="N", x=x, y=BWOARooms.Messhall.y1, z=-4})
        table.insert(BWOARooms.Messhall.els, {dir="S", x=x, y=BWOARooms.Messhall.y2, z=-4})
    end

    for y=BWOARooms.Messhall.y1, BWOARooms.Messhall.y2 do
        if y ~= 12615 then
            table.insert(BWOARooms.Messhall.els, {dir="W", x=BWOARooms.Messhall.x1, y=y, z=-4})
            table.insert(BWOARooms.Messhall.els, {dir="E", x=BWOARooms.Messhall.x2, y=y, z=-4})
        end
    end

    -- pillar
    table.insert(BWOARooms.Messhall.els, {dir="N", x=9964, y=12616, z=-4})
    table.insert(BWOARooms.Messhall.els, {dir="N", x=9965, y=12616, z=-4})
    
    table.insert(BWOARooms.Messhall.els, {dir="S", x=9964, y=12614, z=-4})
    table.insert(BWOARooms.Messhall.els, {dir="S", x=9965, y=12614, z=-4})

    table.insert(BWOARooms.Messhall.els, {dir="W", x=9966, y=12615, z=-4})
    table.insert(BWOARooms.Messhall.els, {dir="E", x=9963, y=12615, z=-4})
end

BWOARooms.Messhall.Build = function ()
    BWOARooms.Messhall.Init()
    BWOAPrepareTools.DarkenLight(9959, 12616, -4)
    BWOAPrepareTools.DarkenLight(9970, 12616, -4)

    BWOABuildTools.ELS(BWOARooms.Messhall.els)

    BWOABuildTools.EmergencyExitW(9959, 12615, -4)

    -- BWOABuildTools.RemoveObject(9959, 12612, -4, "Clock")

    BWOABuildTools.LampOvalW(9959, 12613, -4)
    BWOABuildTools.LampOvalW(9959, 12617, -4)
    BWOABuildTools.LampOvalS(9962, 12620, -4)
    BWOABuildTools.LampOvalS(9967, 12620, -4)
    BWOABuildTools.LampOvalE(9970, 12613, -4)
    BWOABuildTools.LampOvalE(9970, 12617, -4)
    BWOABuildTools.LampOvalN(9962, 12610, -4)
    BWOABuildTools.LampOvalN(9967, 12610, -4)

    BWOABuildTools.LampOvalW(9966, 12615, -4)
    BWOABuildTools.LampOvalE(9963, 12615, -4)

    BWOABuildTools.RemoveObject(9961, 12610, -4, "Green Garbage Bin")
    BWOABuildTools.Fridge(9961, 12610, -4)

    BWOABuildTools.RemoveObject(9968, 12610, -4, "Green Garbage Bin")
    BWOABuildTools.Fridge(9968, 12610, -4)

end

BWOARooms.Messhall.SetEmitters = function ()
    BWOARooms.Messhall.Init()
end

BWOARooms.Messhall.SetFlickers = function ()
    BWOARooms.Messhall.Init()
end

BWOARooms.Messhall.Prepare = function ()
    BWOARooms.Messhall.Init()

    local items
    items = {
        ["Base.Pot"] = 6, ["Base.RoastingPan"] = 6, ["Base.GridlePan"] = 2, ["Base.BottleOpener"] = 1, 
        ["Base.BastingBrush"] = 1, ["Base.TinOpener"] = 1, ["Base.CheeseGrater"] = 1, 
        ["Base.Corkscrew"] = 1, ["Base.GrillBrush"] = 1, ["Base.Ladle"] = 1, 
        ["Base.MuffinTray"] = 2, ["Base.OvenMitt"] = 4, ["Base.Strainer"] = 1,
        ["Base.Whisk"] = 1, ["Base.RollingPin"] = 4, ["Base.Pan"] = 2
    }
    BWOAPrepareTools.AddItemsToContainer(9962, 12610, -4, items, "Counter")

    items = {
        ["Base.Bowl"] = 12, ["Base.RoastingPan"] = 6, ["Base.Saucepan"] = 6, ["Base.BakingPan"] = 6
    }
    BWOAPrepareTools.AddItemsToContainer(9966, 12612, -4, items, "Counter")

    items = {
        ["Base.CuttingBoardWooden"] = 2, ["Base.Matches"] = 20, ["Base.Lighter"] = 2, 
        ["Base.WoodenSpoon"] = 2
    }
    BWOAPrepareTools.AddItemsToContainer(9963, 12610, -4, items, "Counter")

    items = {
        ["Base.Spoon"] = 20, ["Base.Fork"] = 20, ["Base.BreadKnife"] = 20, 
        ["Base.KitchenKnife"] = 2, ["Base.Whetstone"] = 1, 
    }
    BWOAPrepareTools.AddItemsToContainer(9965, 12612, -4, items, "Counter")

    items = {
        ["Base.Carrots"] = 6, ["Base.Tomato"] = 7, 
        ["Base.Onion"] = 8, ["Base.Cabbage"] = 2, ["Base.Cucumber"] = 6, 
        ["Base.BellPepper"] = 3, ["Base.Kale"] = 1, ["Base.Leek"] = 1,
    }
    BWOAPrepareTools.AddItemsToContainer(9961, 12610, -4, items, "Fridge")

    items = {
        ["Base.Lettuce"] = 1, ["Base.Spinach"] = 1, 
        ["Base.Zucchini"] = 6, ["Base.Cauliflower"] = 1, 
        ["Base.Broccoli"] = 2, 
    }
    BWOAPrepareTools.AddItemsToContainer(9968, 12610, -4, items, "Fridge")

    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.BoxOfJars", {x=0.24, y=0.32, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.BoxOfJars", {x=0.24, y=0.73, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.BoxOfJars", {x=0.24, y=0.32, z=0.34, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.CandleBox", {x=0.55, y=0.26, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.CandleBox", {x=0.54, y=0.24, z=0.29, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.CandleBox", {x=0.54, y=0.24, z=0.32, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.CandleBox", {x=0.52, y=0.23, z=0.34, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.CandleBox", {x=0.54, y=0.24, z=0.37, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.CandleBox", {x=0.54, y=0.24, z=0.40, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.TinnedSoup_Box", {x=0.79, y=0.59, z=0.27, rx=0, ry=0, rz=325})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.TinnedSoup", {x=0.85, y=0.80, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.TinnedSoup", {x=0.62, y=0.73, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.WineWhite_Boxed", {x=0.37, y=0.95, z=0.00, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.WineWhite_Boxed", {x=0.73, y=0.93, z=0.00, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.WineWhite_Boxed", {x=0.37, y=0.55, z=0.00, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.WineWhite_Boxed", {x=0.71, y=0.48, z=0.00, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.WineWhite_Boxed", {x=0.34, y=0.88, z=0.12, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.EmptyJar", {x=0.48, y=0.87, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9959, 12610, -4, "Base.EmptyJar", {x=0.47, y=0.72, z=0.27, rx=0, ry=0, rz=0})

    BWOAPrepareTools.AddWorldItem(9960, 12610, -4, "Base.WineRed_Boxed", {x=0.22, y=0.78, z=0.00, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12610, -4, "Base.WineRed_Boxed", {x=0.28, y=0.39, z=0.00, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12610, -4, "Base.OatsRaw", {x=0.05, y=0.25, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12610, -4, "Base.OatsRaw", {x=0.24, y=0.23, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12610, -4, "Base.Cereal", {x=0.59, y=0.34, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12610, -4, "Base.Cereal", {x=0.60, y=0.49, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12610, -4, "Base.Cereal", {x=0.61, y=0.64, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12610, -4, "Base.Cereal", {x=0.60, y=0.87, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12610, -4, "Base.BeerCanPack", {x=0.59, y=0.80, z=0.00, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12610, -4, "Base.BeerCanPack", {x=0.69, y=0.90, z=0.09, rx=0, ry=0, rz=0})
    
    BWOAPrepareTools.AddWorldItem(9962, 12610, -4, "Base.Pot", {x=0.37, y=0.48, z=0.38, rx=0, ry=0, rz=285})
    BWOAPrepareTools.AddWorldItem(9962, 12610, -4, "Base.Saucepan", {x=0.71, y=0.63, z=0.38, rx=0, ry=0, rz=295})
    BWOAPrepareTools.AddWorldItem(9962, 12610, -4, "Base.BakingPan", {x=0.72, y=0.22, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9962, 12610, -4, "Base.BakingPan", {x=0.73, y=0.23, z=0.41, rx=0, ry=0, rz=0})

    BWOAPrepareTools.AddWorldItem(9963, 12610, -4, "Base.CuttingBoardWooden", {x=0.49, y=0.38, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9963, 12610, -4, "Base.CuttingBoardWooden", {x=0.53, y=0.34, z=0.39, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9963, 12610, -4, "Base.Saucepan", {x=0.06, y=0.59, z=0.38, rx=0, ry=0, rz=225})
    
    BWOAPrepareTools.AddWorldItem(9964, 12610, -4, "Base.Pan", {x=0.28, y=0.53, z=0.38, rx=0, ry=0, rz=290})
    BWOAPrepareTools.AddWorldItem(9964, 12610, -4, "Base.Kettle", {x=0.73, y=0.40, z=0.38, rx=0, ry=0, rz=115})
    
    BWOAPrepareTools.AddWorldItem(9965, 12610, -4, "Base.Pot", {x=0.40, y=0.45, z=0.38, rx=0, ry=0, rz=285})
    BWOAPrepareTools.AddWorldItem(9965, 12610, -4, "Base.Ladle", {x=0.85, y=0.10, z=0.51, rx=282, ry=0, rz=0})

    BWOAPrepareTools.AddWorldItem(9966, 12610, -4, "Base.OilOlive", {x=0.23, y=0.30, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9966, 12610, -4, "Base.Pepper", {x=0.22, y=0.47, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9966, 12610, -4, "Base.Salt", {x=0.36, y=0.45, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9966, 12610, -4, "Base.SesameOil", {x=0.34, y=0.25, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9966, 12610, -4, "Base.OilVegetable", {x=0.48, y=0.23, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9966, 12610, -4, "Base.WoodenSpoon", {x=0.42, y=0.61, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9966, 12610, -4, "Base.Hotsauce", {x=0.50, y=0.38, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9966, 12610, -4, "Base.DishCloth", {x=0.78, y=0.53, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9966, 12610, -4, "Base.Timer", {x=0.74, y=0.23, z=0.38, rx=0, ry=0, rz=0})

    BWOAPrepareTools.AddWorldItem(9967, 12610, -4, "Base.CleaningLiquid2", {x=0.19, y=0.25, z=0.38, rx=0, ry=0, rz=315})

    BWOAPrepareTools.AddWorldItem(9960, 12613, -4, "Base.MugWhite", {x=0.82, y=0.52, z=0.35, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12613, -4, "Base.MugWhite", {x=0.67, y=0.95, z=0.35, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12613, -4, "Base.OpenBeans", {x=0.86, y=0.92, z=0.35, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12613, -4, "Base.Fork", {x=0.63, y=0.40, z=0.35, rx=0, ry=0, rz=340})
    BWOAPrepareTools.AddWorldItem(9960, 12613, -4, "Base.Fork", {x=0.69, y=0.75, z=0.35, rx=0, ry=0, rz=10})
    BWOAPrepareTools.AddWorldItem(9960, 12614, -4, "Base.MugWhite", {x=0.80, y=0.51, z=0.35, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12614, -4, "Base.TinCanEmpty", {x=0.84, y=0.32, z=0.35, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12614, -4, "Base.Fork", {x=0.72, y=0.69, z=0.35, rx=0, ry=0, rz=340})
    BWOAPrepareTools.AddWorldItem(9960, 12614, -4, "Base.MugWhite", {x=0.80, y=0.51, z=0.35, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12614, -4, "Base.TinCanEmpty", {x=0.84, y=0.32, z=0.35, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9960, 12614, -4, "Base.Fork", {x=0.72, y=0.69, z=0.35, rx=0, ry=0, rz=340})
    
    BWOAPrepareTools.AddWorldItem(9961, 12614, -4, "Base.MugWhite", {x=0.29, y=0.34, z=0.35, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9961, 12614, -4, "Base.TinCanEmpty", {x=0.12, y=0.22, z=0.35, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9961, 12614, -4, "Base.Fork", {x=0.30, y=0.07, z=0.35, rx=0, ry=0, rz=185})

    BWOAPrepareTools.AddWorldItem(9964, 12614, -4, "Base.PlasticTray", {x=0.56, y=0.62, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9964, 12614, -4, "Base.PlasticTray", {x=0.56, y=0.62, z=0.29, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9964, 12614, -4, "Base.PlasticTray", {x=0.56, y=0.62, z=0.31, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9964, 12614, -4, "Base.PlasticTray", {x=0.56, y=0.62, z=0.33, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9964, 12614, -4, "Base.PlasticTray", {x=0.56, y=0.62, z=0.35, rx=0, ry=0, rz=9})

    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.31, y=0.72, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.31, y=0.72, z=0.28, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.31, y=0.72, z=0.29, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.31, y=0.72, z=0.30, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.31, y=0.72, z=0.31, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.31, y=0.72, z=0.32, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.31, y=0.72, z=0.33, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.31, y=0.72, z=0.34, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.31, y=0.72, z=0.35, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.31, y=0.72, z=0.36, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.63, y=0.71, z=0.27, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.63, y=0.71, z=0.28, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.63, y=0.71, z=0.29, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.63, y=0.71, z=0.30, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.63, y=0.71, z=0.31, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.63, y=0.71, z=0.32, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12614, -4, "Base.Plate", {x=0.63, y=0.71, z=0.33, rx=0, ry=0, rz=0})

    BWOAPrepareTools.AddWorldItem(9963, 12612, -4, "Base.BakingTray", {x=0.56, y=0.78, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9964, 12612, -4, "Base.Bowl", {x=0.26, y=0.68, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9964, 12612, -4, "Base.Bowl", {x=0.26, y=0.93, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9964, 12612, -4, "Base.Bowl", {x=0.51, y=0.93, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9964, 12612, -4, "Base.Bowl", {x=0.51, y=0.68, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9964, 12612, -4, "Base.Cornflour2", {x=0.87, y=0.63, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12612, -4, "Base.CuttingBoardPlastic", {x=0.53, y=0.75, z=0.38, rx=0, ry=0, rz=0})
    BWOAPrepareTools.AddWorldItem(9965, 12612, -4, "Base.KitchenKnife", {x=0.17, y=0.73, z=0.38, rx=0, ry=0, rz=90})
    BWOAPrepareTools.AddWorldItem(9965, 12612, -4, "Base.Onion", {x=0.45, y=0.77, z=0.38, rx=0, ry=0, rz=0})

    BWOAPrepareTools.AddWorldItem(9967, 12612, -4, "Base.Extinguisher", {x=0.16, y=0.87, z=0.00, rx=0, ry=0, rz=305})
    BWOAPrepareTools.AddWorldItem(9967, 12612, -4, "Base.Extinguisher", {x=0.17, y=0.58, z=0.00, rx=0, ry=0, rz=325})
    
    
end


