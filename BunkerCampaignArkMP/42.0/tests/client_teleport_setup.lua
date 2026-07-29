BunkerCampaignArkMP = {}

local function event()
    local result = { handlers = {} }
    result.Add = function(handler) result.handlers[#result.handlers + 1] = handler end
    return result
end

Events = {
    OnCreatePlayer = event(),
    OnServerCommand = event(),
    OnPlayerUpdate = event(),
    LoadGridsquare = event(),
    OnFillWorldObjectContextMenu = event(),
}

local commands = {}
local player = {
    x = 10944,
    y = 9374,
    z = 0,
    square = {},
    getPlayerNum = function(self) return 0 end,
    getCurrentSquare = function(self) return self.square end,
    getX = function(self) return self.x end,
    getY = function(self) return self.y end,
    getZ = function(self) return self.z end,
    teleportTo = function(self, x, y, z)
        self.x, self.y, self.z = x, y, z
        self.teleported = true
    end,
}

isClient = function() return true end
isAdmin = function() return false end
getAccessLevel = function() return "" end
getSpecificPlayer = function(index) return player end
ModData = { request = function(key) end }
sendClientCommand = function(p, module, command, args)
    commands[#commands + 1] = { player=p, module=module, command=command, args=args }
end

function ArkMPClientPlayer() return player end
function ArkMPClientCommands() return commands end

function ArkMPInstallLightFixture(initialActive)
    local properties = {
        has = function() return false end,
        set = function() end,
        unset = function() end,
    }
    local sprite = {
        getName = function() return "test-red-light" end,
        getProperties = function() return properties end,
    }
    local light = {
        className = "IsoLightSwitch",
        active = initialActive == true,
        getSprite = function() return sprite end,
        isActivated = function(self) return self.active end,
        setActive = function()
            error("client reconciliation must not call the networked setActive method")
        end,
        setActivated = function(self, active) self.active = active end,
        switchLight = function(self, active) self.visualActive = active end,
    }
    local objects = {
        size = function() return 1 end,
        get = function(self, index) if index == 0 then return light end end,
    }
    local square = {
        getX = function() return 9960 end,
        getY = function() return 12622 end,
        getZ = function() return -4 end,
        getChunk = function() return {} end,
        getObjects = function() return objects end,
        getRoomID = function() return 1 end,
        setSquareChanged = function() end,
    }
    getCell = function()
        return { getGridSquare = function() return square end }
    end
    instanceof = function(object, className) return object and object.className == className end
    return light, square
end
