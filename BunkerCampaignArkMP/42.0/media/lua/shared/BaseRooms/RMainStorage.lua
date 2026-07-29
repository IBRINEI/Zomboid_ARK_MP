BWOARooms = BWOARooms or {}

BWOARooms.MainStorage = {}

BWOARooms.MainStorage.Init = function ()
    BWOARooms.MainStorage.name = "STORAGEAREAONE"
    BWOARooms.MainStorage.x1 = 9944
    BWOARooms.MainStorage.x2 = 9956
    BWOARooms.MainStorage.y1 = 12627
    BWOARooms.MainStorage.y2 = 12635
    BWOARooms.MainStorage.z = -4
    BWOARooms.MainStorage.ambience = ""

    BWOARooms.MainStorage.vents = {
        {x=9954.5, y=12627, z=-4},
        {x=9950, y=12633.5, z=-4},
        {x=9944, y=12633.5, z=-4},
    }

    BWOARooms.MainStorage.els = {}
    for x=9944, 9949 do
        table.insert(BWOARooms.MainStorage.els, {dir="N", x=x, y=12629, z=-4})
        table.insert(BWOARooms.MainStorage.els, {dir="S", x=x, y=12635, z=-4})
    end

    for y=12629, 12635 do
        table.insert(BWOARooms.MainStorage.els, {dir="W", x=9944, y=y, z=-4})
        if y ~= 12634 then
            table.insert(BWOARooms.MainStorage.els, {dir="E", x=9949, y=y, z=-4})
        end
    end

    for x=9950, 9956 do
        if x ~= 9955 then
            table.insert(BWOARooms.MainStorage.els, {dir="N", x=x, y=12627, z=-4})
        end
        table.insert(BWOARooms.MainStorage.els, {dir="S", x=x, y=12635, z=-4})
    end

    for y=12627, 12635 do
        if y ~= 12634 then
            table.insert(BWOARooms.MainStorage.els, {dir="W", x=9950, y=y, z=-4})
        end
        table.insert(BWOARooms.MainStorage.els, {dir="E", x=9956, y=y, z=-4})
    end

    
end

BWOARooms.MainStorage.Build = function ()
    BWOARooms.MainStorage.Init()
    BWOAPrepareTools.DarkenLight(9956, 12627, -4)
    BWOAPrepareTools.DarkenLight(9949, 12633, -4)

    BWOABuildTools.ELS(BWOARooms.MainStorage.els)

    BWOABuildTools.EmergencyExitN(9955, 12627, -4)

    BWOABuildTools.VentN(9944, 12633, -4)

    BWOABuildTools.LampOvalN(9952, 12627, -4)
    BWOABuildTools.LampOvalS(9952, 12635, -4)
    BWOABuildTools.LampOvalS(9955, 12635, -4)

    BWOABuildTools.LampOvalW(9944, 12630, -4)
    BWOABuildTools.LampOvalW(9944, 12634, -4)
    BWOABuildTools.LampOvalE(9949, 12630, -4)

end

BWOARooms.MainStorage.SetEmitters = function ()
    BWOARooms.MainStorage.Init()
end

BWOARooms.MainStorage.SetFlickers = function ()
    BWOARooms.MainStorage.Init()
end

BWOARooms.MainStorage.Prepare = function ()
    BWOARooms.MainStorage.Init()
    local items

    -- MAIN STORAGE
    items = {["Base.CannedBolognese"] = 11, ["Base.TinnedBeans"] = 14, ["Base.CannedCorn"] = 6}
    BWOAPrepareTools.AddItemsToContainer(9950, 12627, -4, items, "Shelves")

    items = {["Base.CannedMushroomSoup"] = 18, ["Base.TinnedSoup"] = 8}
    BWOAPrepareTools.AddItemsToContainer(9950, 12628, -4, items, "Shelves")

    items = {["Base.CannedCornedBeef"] = 11, ["Base.CannedChili"] = 18}
    BWOAPrepareTools.AddItemsToContainer(9950, 12629, -4, items, "Shelves")

    items = {["Base.TunaTin"] = 23, ["Base.CannedSardines"] = 17}
    BWOAPrepareTools.AddItemsToContainer(9950, 12630, -4, items, "Shelves")

    items = {["Base.CannedPineapple"] = 14, ["Base.CannedFruitCocktail"] = 17}
    BWOAPrepareTools.AddItemsToContainer(9950, 12631, -4, items, "Shelves")

    items = {["Base.CannedPotato2"] = 20, ["Base.CannedCarrots2"] = 12}
    BWOAPrepareTools.AddItemsToContainer(9950, 12632, -4, items, "Shelves")


    items = {["Base.Pasta"] = 18}
    BWOAPrepareTools.AddItemsToContainer(9953, 12630, -4, items, "Shelves")

    items = {["Base.Rice"] = 17}
    BWOAPrepareTools.AddItemsToContainer(9953, 12631, -4, items, "Shelves")

    items = {["Base.OatsRaw"] = 12, ["Base.Cereal"] = 13}
    BWOAPrepareTools.AddItemsToContainer(9953, 12632, -4, items, "Shelves")

    items = {["Base.Flour2"] = 20}
    BWOAPrepareTools.AddItemsToContainer(9953, 12633, -4, items, "Shelves")

    items = {["Base.Sugar"] = 20, ["Base.CocoaPowder"] = 6, ["Base.BakingSoda"] = 8, ["Base.Yeast"] = 12, ["Base.Salt"] = 7}
    BWOAPrepareTools.AddItemsToContainer(9953, 12634, -4, items, "Shelves")

    items = {["Base.JamFruit"] = 33, ["Base.JamMarmalade"] = 41}
    BWOAPrepareTools.AddItemsToContainer(9953, 12635, -4, items, "Shelves")


    items = {["Base.Vinegar2"] = 10, ["Base.OilVegetable"] = 17}
    BWOAPrepareTools.AddItemsToContainer(9956, 12627, -4, items, "Shelves")

    items = {["Base.DriedApricots"] = 2, ["Base.DriedChickpeas"] = 2, ["Base.CannedPineapple"] = 2, ["Base.CannedCornedBeef"] = 2, ["Base.CannedBolognese"] = 2}
    BWOAPrepareTools.AddItemsToContainer(9956, 12628, -4, items, "Shelves")

    items = {["Base.Macandcheese"] = 11, ["Base.DriedWhiteBeans"] = 9}
    BWOAPrepareTools.AddItemsToContainer(9956, 12629, -4, items, "Shelves")

    items = {["Base.DriedLentils"] = 7, ["Base.DehydratedMeatStick"] = 9}
    BWOAPrepareTools.AddItemsToContainer(9956, 12630, -4, items, "Shelves")

    -- items = {["Base.WaterRationCan"] = 60}
    -- BWOAPrepareTools.AddItemsToContainer(9956, 12630, -4, items, "Shelves")

    -- items = {["Base.WaterRationCan"] = 60}
    -- BWOAPrepareTools.AddItemsToContainer(9956, 12631, -4, items, "Shelves")

    items = {["Base.Vodka"] = 20}
    BWOAPrepareTools.AddItemsToContainer(9956, 12632, -4, items, "Shelves")

    -- SECOND STORAGE

    items = {["Base.CleaningLiquid2"] = 16, ["Base.RatPoison"] = 7, ["Base.Sponge"] = 16, ["Base.Bleach"] = 12, ["Base.Soap"] = 18, ["Base.DentalFloos"] = 6, ["Base.Toothpaste"] = 26, ["Base.Toothbrush"] = 30}
    BWOAPrepareTools.AddItemsToContainer(9949, 12635, -4, items, "Shelves")

    items = {["Base.Mop"] = 5, ["Base.Broom"] = 5, ["Base.Bucket"] = 5, ["Base.Bleach"] = 21, ["Base.Gloves_Dish"] = 7}
    BWOAPrepareTools.AddItemsToContainer(9948, 12635, -4, items, "Shelves")

    items = {["Base.Twine"] = 8, ["Base.DuctTape"] = 8, ["Base.Rope"] = 8, ["Base.Woodglue"] = 8}
    BWOAPrepareTools.AddItemsToContainer(9947, 12635, -4, items, "Shelves")

    items = {["Base.WeldingRods"] = 6, ["Base.SheetMetal"] = 20}
    BWOAPrepareTools.AddItemsToContainer(9946, 12635, -4, items, "Shelves")

    items = {["Base.SmallSheetMetal"] = 24, ["Base.ScrapMetal"] = 12, ["Base.BlowTorch"] = 2, ["Base.WeldingMask"] = 2}
    BWOAPrepareTools.AddItemsToContainer(9945, 12635, -4, items, "Shelves")

    items = {["Base.PropaneTank"] = 5}
    BWOAPrepareTools.AddItemsToContainer(9944, 12635, -4, items, "Shelves")

    items = {["Base.BarbedWireStack"] = 4, ["Base.Wire"] = 10, ["Base.Wire"] = 10}
    BWOAPrepareTools.AddItemsToContainer(9947, 12632, -4, items, "Shelves")

    items = {["Base.ClayBrick"] = 160}
    BWOAPrepareTools.AddItemsToContainer(9946, 12632, -4, items, "Shelves")

    items = {["Base.ClayBrick"] = 160}
    BWOAPrepareTools.AddItemsToContainer(9945, 12632, -4, items, "Shelves")

    items = {["Base.ClayBrick"] = 100, ["Base.MasonsChisel"] = 3, ["Base.MasonsTrowel"] = 3}
    BWOAPrepareTools.AddItemsToContainer(9944, 12632, -4, items, "Shelves")

    items = {["Base.ConcretePowder"] = 10}
    BWOAPrepareTools.AddItemsToContainer(9944, 12629, -4, items, "Shelves")

    items = {["Base.PlasterPowder"] = 10}
    BWOAPrepareTools.AddItemsToContainer(9945, 12629, -4, items, "Shelves")

    items = {["Base.PaintWhite"] = 10}
    BWOAPrepareTools.AddItemsToContainer(9946, 12629, -4, items, "Shelves")

    items = {["Base.PaintWhite"] = 10}
    BWOAPrepareTools.AddItemsToContainer(9947, 12629, -4, items, "Shelves")

    items = {["Base.PaintGreen"] = 10}
    BWOAPrepareTools.AddItemsToContainer(9948, 12629, -4, items, "Shelves")

    items = {["Base.Paintbrush"] = 8, ["Base.PaintGreen"] = 4}
    BWOAPrepareTools.AddItemsToContainer(9949, 12629, -4, items, "Shelves")


    
end


