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
safeInsert("ArmyHangarOutfit",       "ContaminantDetector", 0.05)
safeInsert("ArmyStorageElectronics",  "ContaminantDetector", 0.5)
safeInsert("ArmyStorageOutfit",       "ContaminantDetector", 0.05)
safeInsert("ControlRoomCounter",      "ContaminantDetector", 0.05)
safeInsert("CrateElectronics",        "ContaminantDetector", 0.05)
safeInsert("CrateRandomJunk",         "ContaminantDetector", 0.001)
safeInsert("EngineerTools",           "ContaminantDetector", 0.05)
safeInsert("LockerArmyBedroom",       "ContaminantDetector", 0.5)
safeInsert("ElectronicStoreMisc",     "ContaminantDetector", 0.01)
safeInsert("GarageMetalwork",         "ContaminantDetector", 0.005)

-- RadiationMag (How To Detect Radiation)
safeInsert("BookstoreMisc",           "RadiationMag", 2)
safeInsert("CrateMagazines",          "RadiationMag", 0.75)
safeInsert("LibraryBooks",            "RadiationMag", 0.75)
safeInsert("LivingRoomShelf",         "RadiationMag", 0.075)
safeInsert("LivingRoomShelfNoTapes",  "RadiationMag", 0.075)
safeInsert("MagazineRackMixed",       "RadiationMag", 0.3)
safeInsert("PostalStorageMisc",       "RadiationMag", 0.2)
