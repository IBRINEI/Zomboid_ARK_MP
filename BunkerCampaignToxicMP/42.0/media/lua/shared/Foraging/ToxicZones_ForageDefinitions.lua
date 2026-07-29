require 'Foraging/forageSystem'

Events.onAddForageDefs.Add(function()

--New items

	local RadiationMag = {
	type = "Base.RadiationMag",
	xp = 10,
	forceOutside = false,
        categories = { "Junk" },
		zones           = {
			Forest              = 20,
			DeepForest          = 20,
			Vegitation          = 20,
			FarmLand            = 20,
			Farm                = 20,
			TrailerPark         = 20,
			TownZone            = 20,
			Nav                 = 20,
		},
	};

	local ContaminantDetector = {
	type = "Base.ContaminantDetector",
	xp = 10,
	forceOutside = false,
        categories = { "Trash" },
		zones           = {
			Forest              = 5,
			DeepForest          = 5,
			Vegitation          = 5,
			FarmLand            = 5,
			Farm                = 5,
			TrailerPark         = 5,
			TownZone            = 5,
			Nav                 = 5,
		},
	};

--Adding them to the foraging system
forageSystem.addItemDef(RadiationMag);
forageSystem.addItemDef(ContaminantDetector);

end)