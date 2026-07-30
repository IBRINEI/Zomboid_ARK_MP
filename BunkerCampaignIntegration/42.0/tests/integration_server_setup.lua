BunkerCampaignToxicMP = {
    Server = {
        addAmbientProvider=function() return true end,
    },
}
BunkerCampaignArkMP = { Constants={} }

BWOARooms = {
    Laboratory = {
        Init=function()
            BWOARooms.Laboratory.name = "LABORATORY"
            BWOARooms.Laboratory.x1, BWOARooms.Laboratory.x2 = 9900, 9904
            BWOARooms.Laboratory.y1, BWOARooms.Laboratory.y2 = 12000, 12004
            BWOARooms.Laboratory.z = -4
            BWOARooms.Laboratory.vents = { {x=9902,y=12000,z=-4} }
        end,
    },
    Garage = {
        Init=function()
            BWOARooms.Garage.name = "GARAGE"
            BWOARooms.Garage.x1, BWOARooms.Garage.x2 = 9905, 9910
            BWOARooms.Garage.y1, BWOARooms.Garage.y2 = 12000, 12004
            BWOARooms.Garage.z = -4
            BWOARooms.Garage.vents = { {x=9905,y=12002,z=-4} }
        end,
    },
}
