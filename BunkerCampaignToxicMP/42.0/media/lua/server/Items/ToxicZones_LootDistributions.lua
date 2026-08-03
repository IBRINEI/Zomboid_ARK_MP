require 'Items/ProceduralDistributions'

-- Safe insert helper: only add to distribution lists that exist in this build
local function safeInsert(listName, itemName, chance)
	local entry = ProceduralDistributions.list[listName]
	if entry and entry.items then
		table.insert(entry.items, itemName)
		table.insert(entry.items, chance)
	end
end

-- ContaminantDetector (Geiger Counter)
safeInsert("ArmyHangarOutfit",       "Base.ContaminantDetector", 0.05)
safeInsert("ArmyStorageElectronics",  "Base.ContaminantDetector", 0.5)
safeInsert("ArmyStorageOutfit",       "Base.ContaminantDetector", 0.05)
safeInsert("ControlRoomCounter",      "Base.ContaminantDetector", 0.05)
safeInsert("CrateElectronics",        "Base.ContaminantDetector", 0.05)
safeInsert("CrateRandomJunk",         "Base.ContaminantDetector", 0.001)
safeInsert("EngineerTools",           "Base.ContaminantDetector", 0.05)
safeInsert("LockerArmyBedroom",       "Base.ContaminantDetector", 0.5)
safeInsert("ElectronicStoreMisc",     "Base.ContaminantDetector", 0.01)
safeInsert("GarageMetalwork",         "Base.ContaminantDetector", 0.005)

-- RadiationMag (How To Detect Radiation)
safeInsert("BookstoreMisc",           "Base.RadiationMag", 2)
safeInsert("CrateMagazines",          "Base.RadiationMag", 0.75)
safeInsert("LibraryBooks",            "Base.RadiationMag", 0.75)
safeInsert("LivingRoomShelf",         "Base.RadiationMag", 0.075)
safeInsert("LivingRoomShelfNoTapes",  "Base.RadiationMag", 0.075)
safeInsert("MagazineRackMixed",       "Base.RadiationMag", 0.3)
safeInsert("PostalStorageMisc",       "Base.RadiationMag", 0.2)
