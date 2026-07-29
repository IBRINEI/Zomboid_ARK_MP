BWOARooms = BWOARooms or {}

BWOARooms.FoodGarden = {}

BWOARooms.FoodGarden.Init = function ()
    BWOARooms.FoodGarden.name = "FOODGARDEN"
    BWOARooms.FoodGarden.x1 = 9944
    BWOARooms.FoodGarden.x2 = 9956
    BWOARooms.FoodGarden.y1 = 12608
    BWOARooms.FoodGarden.y2 = 12614
    BWOARooms.FoodGarden.z = -4
    BWOARooms.FoodGarden.ambience = ""

    BWOARooms.FoodGarden.vents = {
        {x=9944, y=12611.5, z=-4},
    }

    BWOARooms.FoodGarden.els = {}
    for x=9944, 9956 do
        table.insert(BWOARooms.FoodGarden.els, {dir="S", x=x, y=12614, z=-4})
        table.insert(BWOARooms.FoodGarden.els, {dir="N", x=x, y=12608, z=-4})
    end

    for y=12608, 12614 do
        table.insert(BWOARooms.FoodGarden.els, {dir="W", x=9944, y=y, z=-4})
        if y ~= 12611 then
            table.insert(BWOARooms.FoodGarden.els, {dir="E", x=9956, y=y, z=-4})
        end
    end
end

BWOARooms.FoodGarden.Build = function ()
    BWOARooms.FoodGarden.Init()

    BWOAPrepareTools.DarkenLight(9956, 12612, -4)

    BWOABuildTools.ELS(BWOARooms.FoodGarden.els)

    for x=BWOARooms.FoodGarden.x1, BWOARooms.FoodGarden.x2 do
        for y=BWOARooms.FoodGarden.y1, BWOARooms.FoodGarden.y2 do
            BWOABuildTools.RemoveObject(x, y, -4, "Beds")
        end
    end

    for y=BWOARooms.FoodGarden.y1, BWOARooms.FoodGarden.y2 do
        BWOABuildTools.RemoveObject(9944, y, -4, "Locker")
    end

    BWOABuildTools.RemoveObject(9944, 12608, -4, "Chair")
    BWOABuildTools.RemoveObject(9944, 12614, -4, "Chair")
    
    BWOABuildTools.VentN(9944, 12611, -4)

    -- farmplots
    local seeds = {
        "BellPepper", "Tomato", "Broccoli", "Cabbages" , "Carrots" , "Cauliflower", "Corn", 
        "Cucumber", "Garlic", "Greenpeas", 'Lettuce', "Onion", "Potatoes", "Potatoes", "Potatoes", "Potatoes", 
        "Soybeans", "Spinach", "Strawberryplant", "SugarBeets", "Turnip", "Zucchini"
    }

    BWOABuildTools.FarmPlot(9944, 12608, -4, "Spinach")
    BWOABuildTools.FarmPlot(9945, 12608, -4, "Spinach")
    BWOABuildTools.FarmPlot(9946, 12608, -4, "Spinach")
    BWOABuildTools.FarmPlot(9947, 12608, -4, "Lettuce")
    BWOABuildTools.FarmPlot(9948, 12608, -4, "Lettuce")
    BWOABuildTools.FarmPlot(9949, 12608, -4, "Lettuce")
    BWOABuildTools.FarmPlot(9950, 12608, -4, "Greenpeas")
    BWOABuildTools.FarmPlot(9951, 12608, -4, "Greenpeas")
    BWOABuildTools.FarmPlot(9952, 12608, -4, "Greenpeas")
    BWOABuildTools.FarmPlot(9953, 12608, -4, "Zucchini")
    BWOABuildTools.FarmPlot(9954, 12608, -4, "Zucchini")
    BWOABuildTools.FarmPlot(9955, 12608, -4, "Zucchini")

    BWOABuildTools.FarmPlot(9944, 12610, -4, "Cabbages")
    BWOABuildTools.FarmPlot(9945, 12610, -4, "Cabbages")
    BWOABuildTools.FarmPlot(9946, 12610, -4, "Cabbages")
    BWOABuildTools.FarmPlot(9947, 12610, -4, "Broccoli")
    BWOABuildTools.FarmPlot(9948, 12610, -4, "Broccoli")
    BWOABuildTools.FarmPlot(9949, 12610, -4, "Broccoli")
    BWOABuildTools.FarmPlot(9950, 12610, -4, "Cauliflower")
    BWOABuildTools.FarmPlot(9951, 12610, -4, "Cauliflower")
    BWOABuildTools.FarmPlot(9952, 12610, -4, "Cauliflower")
    BWOABuildTools.FarmPlot(9953, 12610, -4, "Cucumber")
    BWOABuildTools.FarmPlot(9954, 12610, -4, "Cucumber")
    BWOABuildTools.FarmPlot(9955, 12610, -4, "Cucumber")

    BWOABuildTools.FarmPlot(9944, 12612, -4, "Tomato")
    BWOABuildTools.FarmPlot(9945, 12612, -4, "Tomato")
    BWOABuildTools.FarmPlot(9946, 12612, -4, "Tomato")
    BWOABuildTools.FarmPlot(9947, 12612, -4, "Tomato")
    BWOABuildTools.FarmPlot(9948, 12612, -4, "BellPepper")
    BWOABuildTools.FarmPlot(9949, 12612, -4, "BellPepper")
    BWOABuildTools.FarmPlot(9950, 12612, -4, "BellPepper")
    BWOABuildTools.FarmPlot(9951, 12612, -4, "BellPepper")
    BWOABuildTools.FarmPlot(9952, 12612, -4, "Carrots")
    BWOABuildTools.FarmPlot(9953, 12612, -4, "Carrots")
    BWOABuildTools.FarmPlot(9954, 12612, -4, "Carrots")
    BWOABuildTools.FarmPlot(9955, 12612, -4, "Carrots")

    BWOABuildTools.FarmPlot(9944, 12614, -4, "Onion")
    BWOABuildTools.FarmPlot(9945, 12614, -4, "Onion")
    BWOABuildTools.FarmPlot(9946, 12614, -4, "Garlic")
    BWOABuildTools.FarmPlot(9947, 12614, -4, "Garlic")
    BWOABuildTools.FarmPlot(9948, 12614, -4, "Potatoes")
    BWOABuildTools.FarmPlot(9949, 12614, -4, "Potatoes")
    BWOABuildTools.FarmPlot(9950, 12614, -4, "Potatoes")
    BWOABuildTools.FarmPlot(9951, 12614, -4, "Potatoes")
    BWOABuildTools.FarmPlot(9952, 12614, -4, "Potatoes")
    BWOABuildTools.FarmPlot(9953, 12614, -4, "Potatoes")
    BWOABuildTools.FarmPlot(9954, 12614, -4, "Potatoes")
    BWOABuildTools.FarmPlot(9955, 12614, -4, "Potatoes")

    BWOABuildTools.WaterPipe(9950, 12614, -4, WPIso.pipeSprites.ns)
    BWOABuildTools.WaterPipe(9950, 12613, -4, WPIso.pipeSprites.ns)
    BWOABuildTools.WaterValve(9950, 12613, -4)
    BWOABuildTools.WaterPipe(9950, 12612, -4, WPIso.pipeSprites.ns)
    BWOABuildTools.WaterPipe(9950, 12611, -4, WPIso.pipeSprites.ns)
    BWOABuildTools.WaterSprinkler(9950, 12611, -4)

    for y=12608, 12614, 2 do
        BWOABuildTools.LampCustom(9944, y, -4, "lighting_indoor_03_16")
        for x=9945, 9954 do
            BWOABuildTools.LampCustom(x, y, -4, "lighting_indoor_03_18")
        end
        BWOABuildTools.LampCustom(9955, y, -4, "lighting_indoor_03_17")
    end

end

BWOARooms.FoodGarden.SetEmitters = function ()
    for y=12580, 12605, 5 do
        BWOASound.AddToObject({x=9961.5, y=y + 0.5, z=-4, sound="AmbientVent"})
        BWOASound.AddToObject({x=9973.5, y=y + 0.5, z=-4, sound="AmbientVent"})
    end
end

BWOARooms.FoodGarden.Prepare = function ()
end


