BWOARooms = BWOARooms or {}

BWOARooms.Corridor = {}

BWOARooms.Corridor.Init = function ()
    BWOARooms.Corridor.name = "CORRIDOR"
    -- BWOARooms.Corridor.x1 = 9957
    -- BWOARooms.Corridor.x2 = 9972
    -- BWOARooms.Corridor.y1 = 12608
    -- BWOARooms.Corridor.y2 = 12642
    BWOARooms.Corridor.z = -4

    BWOARooms.Corridor.vents = {
        {x=9954.5, y=12624, z=-4},
        {x=9957, y=12648.5, z=-4},
        {x=9957, y=12640.5, z=-4},
        {x=9954.5, y=12623, z=-4},
        {x=9957, y=12610.5, z=-4},
        {x=9957, y=12602.5, z=-4},
        {x=9963.5, y=12641, z=-4},
        {x=9969.5, y=12641, z=-4},
        {x=9970, y=12634.5, z=-4},
        {x=9970, y=12629.5, z=-4},
        {x=9970, y=12623.5, z=-4},
        {x=9970, y=12614.5, z=-4},
        {x=9965.5, y=12608.5, z=-4},
        {x=9971.5, y=12618.5, z=-4},
        {x=9971.5, y=12645.5, z=-4},
        {x=9967.5, y=12645.5, z=-4},
        {x=9963.5, y=12645.5, z=-4},
    }

    BWOARooms.Corridor.els = {}

    for x=9950, 9956 do
        if x ~= 9955 then
            table.insert(BWOARooms.Corridor.els, {dir="N", x=x, y=12624, z=-4})
        end
    end

    for y=12623, 12600, -1 do
        if y ~= 12611 and y ~= 12601 then
            table.insert(BWOARooms.Corridor.els, {dir="W", x=9957, y=y, z=-4})
        end
    end

    table.insert(BWOARooms.Corridor.els, {dir="N", x=9957, y=12600, z=-4})
    table.insert(BWOARooms.Corridor.els, {dir="N", x=9958, y=12600, z=-4})

    for y=12600, 12607 do
        if y ~= 12606 then
            table.insert(BWOARooms.Corridor.els, {dir="E", x=9958, y=y, z=-4})
        end
    end

    for x=9959, 9972 do
        table.insert(BWOARooms.Corridor.els, {dir="N", x=x, y=12608, z=-4})
    end

    for y=12608, 12642 do
        if y ~= 12615 and y ~= 12620 and y ~= 12630 and y ~= 12635 then
            table.insert(BWOARooms.Corridor.els, {dir="E", x=9972, y=y, z=-4})
        end
    end

    for x=9972, 9959, -1 do
        table.insert(BWOARooms.Corridor.els, {dir="S", x=x, y=12642, z=-4})
    end

    for y=12643, 12650 do
        if y ~= 12644 then
            table.insert(BWOARooms.Corridor.els, {dir="E", x=9958, y=y, z=-4})
        end
    end

    table.insert(BWOARooms.Corridor.els, {dir="S", x=9958, y=12650, z=-4})
    table.insert(BWOARooms.Corridor.els, {dir="S", x=9957, y=12650, z=-4})

    for y=12650, 12627, -1 do
        if y ~= 12649 and y ~= 12639 then
            table.insert(BWOARooms.Corridor.els, {dir="W", x=9957, y=y, z=-4})
        end
    end

    for x=9956, 9950, -1 do
        if x ~= 9955 then
            table.insert(BWOARooms.Corridor.els, {dir="S", x=x, y=12626, z=-4})
        end
    end

    table.insert(BWOARooms.Corridor.els, {dir="W", x=9950, y=12626, z=-4})
    table.insert(BWOARooms.Corridor.els, {dir="W", x=9950, y=12625, z=-4})
    table.insert(BWOARooms.Corridor.els, {dir="W", x=9950, y=12624, z=-4})

    ---

    for y=12640, 12610, -1 do
        if y ~= 12615 and y ~= 12625 and y ~= 12633 then
            table.insert(BWOARooms.Corridor.els, {dir="E", x=9958, y=y, z=-4})
        end

        if y ~= 12615 and y ~= 12624 and y ~= 12630 and y ~= 12635 then
            table.insert(BWOARooms.Corridor.els, {dir="W", x=9971, y=y, z=-4})
        end
    end

    for x=9959, 9970 do
        table.insert(BWOARooms.Corridor.els, {dir="S", x=x, y=12609, z=-4})
        if x ~= 9968 and x ~= 9962 then
            table.insert(BWOARooms.Corridor.els, {dir="N", x=x, y=12641, z=-4})
        end
    end
end

BWOARooms.Corridor.Build = function ()
    BWOARooms.Corridor.Init()

    BWOAPrepareTools.DarkenLight(9950, 12626, -4)

    BWOABuildTools.ELS(BWOARooms.Corridor.els)

    BWOABuildTools.EmergencyExitW(9950, 12625, -4)

    BWOABuildTools.LampOvalN(9953, 12624, -4)
    BWOABuildTools.LampOvalW(9957, 12620, -4)
    BWOABuildTools.LampOvalW(9957, 12613, -4)
    BWOABuildTools.LampOvalW(9957, 12605, -4)
    BWOABuildTools.LampOvalN(9962, 12608, -4)
    BWOABuildTools.LampOvalN(9968, 12608, -4)
    BWOABuildTools.LampOvalE(9972, 12612, -4)
    BWOABuildTools.LampOvalE(9972, 12618, -4)
    BWOABuildTools.LampOvalE(9972, 12624, -4)
    BWOABuildTools.LampOvalE(9972, 12631, -4)
    BWOABuildTools.LampOvalE(9972, 12637, -4)
    BWOABuildTools.LampOvalS(9968, 12642, -4)
    BWOABuildTools.LampOvalS(9962, 12642, -4)
    BWOABuildTools.LampOvalW(9957, 12645, -4)
    BWOABuildTools.LampOvalW(9957, 12637, -4)
    BWOABuildTools.LampOvalW(9957, 12630, -4)
    BWOABuildTools.LampOvalS(9953, 12626, -4)

    BWOABuildTools.LampOvalN(9958, 12600, -4)
    BWOABuildTools.LampOvalS(9958, 12650, -4)

    BWOABuildTools.LampOvalS(9958, 12650, -4)

    BWOABuildTools.LampOvalS(9953, 12626, -4)

    BWOABuildTools.VentW(9965, 12608, -4)
    BWOABuildTools.VentN(9971, 12618, -4)

    -- "fencing_damaged_01_138"
    -- "fencing_damaged_01_137"

end

BWOARooms.Corridor.Prepare = function ()
    BWOARooms.Corridor.Init()

    local spray1 = BanditCompatibility.InstanceItem("Base.KnapsackSprayer")
    if spray1 then
        local fluidContainer = spray1:getFluidContainer()
        if fluidContainer then
            fluidContainer:Empty()
            fluidContainer:addFluid("NBCSolution", 16)
        end
    end
    BWOAPrepareTools.AddWorldItemSpecial(9952, 12624, -4, spray1, {x=0.29, y=0.27, z=0.00, rx=0, ry=0, rz=270})

    local spray2 = BanditCompatibility.InstanceItem("Base.KnapsackSprayer")
    if spray2 then
        local fluidContainer = spray2:getFluidContainer()
        if fluidContainer then
            fluidContainer:Empty()
            fluidContainer:addFluid("NBCSolution", 7)
        end
    end
    BWOAPrepareTools.AddWorldItemSpecial(9952, 12624, -4, spray2, {x=0.74, y=0.29, z=0.00, rx=0, ry=0, rz=270})

end

BWOARooms.Corridor.SetEmitters = function ()
    BWOARooms.Corridor.Init()

    BWOASound.AddToObject({x=9957, y=12644.5, z=-4, sound="AmbientPlumbing"})
    BWOASound.AddToObject({x=9957, y=12621.5, z=-4, sound="AmbientPlumbing"})
    BWOASound.AddToObject({x=9971.5, y=12608, z=-4, sound="AmbientPlumbing"})
end

