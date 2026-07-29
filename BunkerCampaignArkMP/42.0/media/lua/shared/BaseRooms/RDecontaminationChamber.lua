BWOARooms = BWOARooms or {}

BWOARooms.DecontaminationChamber = {}

BWOARooms.DecontaminationChamber.cooldown = 0

BWOARooms.DecontaminationChamber.Init = function ()
    BWOARooms.DecontaminationChamber.name = "DECONTAMINATION_CHAMBER"
    BWOARooms.DecontaminationChamber.x1 = 9944
    BWOARooms.DecontaminationChamber.x2 = 9949
    BWOARooms.DecontaminationChamber.y1 = 12622
    BWOARooms.DecontaminationChamber.y2 = 12628
    BWOARooms.DecontaminationChamber.z = -4
    BWOARooms.DecontaminationChamber.ambience = ""

    BWOARooms.DecontaminationChamber.vents = {}

    BWOARooms.DecontaminationChamber.els = {}
end

BWOARooms.DecontaminationChamber.Build = function ()
    BWOARooms.DecontaminationChamber.Init()

    BWOAPrepareTools.DarkenLight(9944, 12627, -4)

    BWOABuildTools.ELS(BWOARooms.DecontaminationChamber.els)

    BWOABuildTools.LampOvalW(9948, 12625, -4)
    BWOABuildTools.LampOvalE(9945, 12625, -4)

    BWOABuildTools.Generic(9946, 12624, -4, "street_decoration_01_14")
    BWOABuildTools.Generic(9947, 12624, -4, "street_decoration_01_14")
    BWOABuildTools.Generic(9946, 12626, -4, "street_decoration_01_14")
    BWOABuildTools.Generic(9947, 12626, -4, "street_decoration_01_14")
end

BWOARooms.DecontaminationChamber.SetEmitters = function ()
    BWOARooms.DecontaminationChamber.Init()
end

BWOARooms.DecontaminationChamber.SetFlickers = function ()
    BWOARooms.DecontaminationChamber.Init()
end

BWOARooms.DecontaminationChamber.Prepare = function ()
    BWOARooms.DecontaminationChamber.Init()
end

BWOARooms.DecontaminationChamber.Logic = function ()
    -- The single-player automatic sequence is deliberately disabled in MP.
end
