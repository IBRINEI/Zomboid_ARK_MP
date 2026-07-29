BWOABuildTools = BWOABuildTools or {}

-- The original The Ark builds from client Lua and always transmits changes to
-- the server.  The MP fork constructs the bunker on the authoritative server,
-- so new objects must be sent in the opposite direction.
local function transmitComplete(object)
    if not object then return end
    if isServer() then
        object:transmitCompleteItemToClients()
    elseif isClient() then
        object:transmitCompleteItemToServer()
    end
end

BWOABuildTools.Floor = function(x, y, z, spriteName, cracks, blood)
    local cell = getCell()
    local square = cell:getGridSquare(x, y, z)
    if square == nil and getWorld():isValidSquare(x, y, z) then
        square = cell:createNewGridSquare(x, y, z, true)
    end
    if not square or not square:getChunk() then return end

    local obj = IsoObject.new(square, spriteName, "")
    obj:setAttachedAnimSprite(ArrayList.new())

    if cracks and ZombRand(3) == 0 then
        local crackSprite = "floors_overlay_street_01_" .. tostring(1 + ZombRand(43))
        obj:getAttachedAnimSprite():add(getSprite(crackSprite):newInstance())
    end

    if blood and ZombRand(3) == 0 then
        local bloodSprite = "overlay_blood_floor_01_" .. tostring(1 + ZombRand(13))
        obj:getAttachedAnimSprite():add(getSprite(bloodSprite):newInstance())
    end

    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()

end

BWOABuildTools.WindowFrame = function(x, y, z, spriteName, north)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoWindowFrame.new(getCell(), square, getSprite(spriteName), north)
    if not obj then return end

    local md = obj:getModData()
    md.climbForbidden = true

    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
    square:RecalcAllWithNeighbours(true)
    buildUtil.setHaveConstruction(square, true)
end

BWOABuildTools.Window = function(x, y, z, spriteName, north)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoWindow.new(getCell(), square, getSprite(spriteName), north)
    if not obj then return end

    local md = obj:getModData()
    md.climbForbidden = true

    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
    square:RecalcAllWithNeighbours(true)
    buildUtil.setHaveConstruction(square, true)
end

BWOABuildTools.Wall = function(x, y, z, spriteName)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoObject.new(square, spriteName, "")
    if not obj then return end

    obj:setType(IsoObjectType.wall)

    local sprite = obj:getSprite()
    local props = sprite:getProperties()
    obj:setAttachedAnimSprite(ArrayList.new())
    if props:has(IsoFlagType.WallW) then
        obj:getAttachedAnimSprite():add(getSprite("overlay_grime_wall_01_0"):newInstance())

        local rnd = 10
        if rnd == 1 then
            obj:getAttachedAnimSprite():add(getSprite("overlay_graffiti_wall_01_10"):newInstance())
        end
    elseif props:has(IsoFlagType.WallN) then
        obj:getAttachedAnimSprite():add(getSprite("overlay_grime_wall_01_1"):newInstance())
    elseif props:has(IsoFlagType.WallNW) then
        obj:getAttachedAnimSprite():add(getSprite("overlay_grime_wall_01_2"):newInstance())
    end

    local crackSprite = "d_wallcracks_1_" .. tostring(1 + ZombRand(70))
    obj:getAttachedAnimSprite():add(getSprite(crackSprite):newInstance())

    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
    square:RecalcAllWithNeighbours(true)
    buildUtil.setHaveConstruction(square, true)
end

BWOABuildTools.Door = function(x, y, z, north, sprite, locked)
    local cell = getCell()
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    
    for s, number in string.gmatch(sprite, "(.+)_(%d+)") do

        if not north then
            north = true
            if (number % 2 == 0) then
                north = false
            end
        end

        obj = IsoDoor.new(cell, square, sprite, north)
        square:AddSpecialObject(obj)
        transmitComplete(obj)
        buildUtil.setHaveConstruction(square, true)
        square:setSquareChanged()

        if locked then
            obj:setLocked(true)
            obj:setLockedByKey(true)
            obj:setIsLocked(true)
        end
    end
end

BWOABuildTools.Generic = function(x, y, z, spriteName)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoObject.new(square, spriteName, "")
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
end

BWOABuildTools.Bed = function(x, y, z, spriteName)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoObject.new(square, spriteName, "")
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
end

BWOABuildTools.Stove = function(x, y, z, spriteName)
    local cell = getCell()
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoStove.new(cell, square, getSprite(spriteName))
    obj:createContainersFromSpriteProperties()
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
end

BWOABuildTools.WasherDryer = function(x, y, z, spriteName, activated)
    local cell = getCell()
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoCombinationWasherDryer.new(cell, square, getSprite(spriteName))
    obj:setMovedThumpable(true)
    obj:createContainersFromSpriteProperties()
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
    obj:setActivated(activated)
end

BWOABuildTools.Jukebox = function(x, y, z, spriteName, activated)
    local cell = getCell()
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoJukebox.new(cell, square, getSprite(spriteName))
    obj:setMovedThumpable(true)
    obj:createContainersFromSpriteProperties()
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
    obj:SetPlaying(activated)
end

BWOABuildTools.Generator = function(x, y, z, fuel, condition, connected, active, old)
    local itemType = "Base.Generator"
    if old then
        itemType = "Base.Generator_Old"
    end
    local cell = getCell()
    local square = cell:getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local genItem = BanditCompatibility.InstanceItem(itemType)
    local generator = IsoGenerator.new(genItem, cell, square)
    generator:setMovedThumpable(true)
    generator:setCondition(condition)
    generator:setFuel(fuel)
    generator:setConnected(connected)
    generator:setActivated(active)
end

BWOABuildTools.Mannequin = function(x, y, z, scriptName, dir)
    local spriteName = "location_shop_mall_01_68"
    local item = BanditCompatibility.InstanceItem("Moveables."..spriteName)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoMannequin.new(getCell(), square, getSprite(spriteName))
    obj:getCustomSettingsFromItem(item)
    obj:setDir(dir)
    obj:setMannequinScriptName(scriptName)

    for i=1,obj:getContainerCount() do
        obj:getContainerByIndex(i-1):clear()
    end

    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
end



BWOABuildTools.Fireplace = function(x, y, z, spriteName)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoFireplace.new(getCell(), square, getSprite(spriteName))
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    obj:addFuel(100)
    obj:setLit(true)
    square:setSquareChanged()
end

BWOABuildTools.WaterPump = function(x, y, z)
    local sprite = getSprite(WPIso.pumpSprites.ns)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    if type(WPIso.GetPump) == "function" then
        local existing = WPIso.GetPump(square)
        if existing then return existing end
    end

    local object = IsoClothingDryer.new(square:getCell(), square, sprite)
    object:setActivated(true)
    object:setMovedThumpable(true)
    object:createContainersFromSpriteProperties()
    square:AddSpecialObject(object)
    transmitComplete(object)
    square:setSquareChanged()
    -- WaterPipes keeps WPSound in client Lua.  The MP fork builds this object
    -- on the dedicated server, where the table intentionally does not exist.
    -- WPIso.SyncPump will attach the loop on each client after pump sync.
    if not isServer() and type(WPSound) == "table" and type(WPSound.AddToObject) == "function" then
        WPSound.AddToObject(object, "WPWaterPumpLoop", 0.5)
    end
    if isServer() and type(GetWPModData) == "function" then
        local gmd = GetWPModData()
        if type(gmd) == "table" then
            if type(gmd.Pumps) ~= "table" then gmd.Pumps = {} end
            local key
            if type(WPUtils) == "table" and type(WPUtils.Coords2Id) == "function" then
                key = WPUtils.Coords2Id(x, y, z)
            else
                key = tostring(x) .. "-" .. tostring(y) .. "-" .. tostring(z)
            end
            if type(gmd.Pumps[key]) ~= "table" then
                gmd.Pumps[key] = {
                    x = x,
                    y = y,
                    z = z,
                    efficiency = 100,
                    filter = 100,
                    active = true,
                    burn = false,
                }
            end
            if type(TransmitWPModData) == "function" then TransmitWPModData() end
        end
    else
        WPVirtual.PumpAdd(x, y, z)
        WPVirtual.PumpAddFilter(x, y, z)
        WPVirtual.PumpActivate(x, y, z, true)
    end

    return object
end

BWOABuildTools.WaterPipe = function(x, y, z, spriteName)
    local sprite = getSprite(spriteName)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local object = IsoObject.new(square:getCell(), square, sprite)
    square:AddSpecialObject(object)
    transmitComplete(object)
    WPIso.BuildPipe(square)
end

BWOABuildTools.WaterValve = function(x, y, z)
    local sprite = getSprite(WPIso.valveSprites.ns)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local object = IsoObject.new(square:getCell(), square, sprite)
    square:AddSpecialObject(object)
    transmitComplete(object)
    WPVirtual.ValveAdd(x, y, z, 200)
    WPVirtual.ValveSwitch(x, y, z, true)
end

BWOABuildTools.Flowmeter = function(x, y, z)
    local sprite = getSprite(WPIso.flowmeterSprites.we)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local object = IsoObject.new(square:getCell(), square, sprite)
    square:AddSpecialObject(object)
    transmitComplete(object)
    WPVirtual.FlowmeterAdd(x, y, z)
end

BWOABuildTools.WaterSprinkler = function(x, y, z)
    local sprite = getSprite(WPIso.waterSprinklersSprites[1])
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local object = IsoObject.new(square:getCell(), square, sprite)
    square:AddSpecialObject(object)
    transmitComplete(object)
    WPVirtual.SprinklerAdd(x, y, z, 200)
end

BWOABuildTools.VentN = function(x, y, z)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoObject.new(square, "rooftop_furniture_4", "")
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
end

BWOABuildTools.VentW = function(x, y, z)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoObject.new(square, "rooftop_furniture_5", "")
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
end

BWOABuildTools.BookshelfW = function(x, y, z)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoObject.new(square, "furniture_shelving_01_44", "")
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
end

BWOABuildTools.Fridge = function(x, y, z)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoObject.new(square, "appliances_refrigeration_01_40", "")
    square:AddSpecialObject(obj)
    local fridgeContainer = obj:getContainerByType("fridge")
    if fridgeContainer then
        fridgeContainer:setExplored(true)
        fridgeContainer:clear()
        fridgeContainer:removeAllItems()
    end

    local freezerContainer = obj:getContainerByType("freezer")
    if freezerContainer then
        freezerContainer:setExplored(true)
        freezerContainer:clear()
        freezerContainer:removeAllItems()
    end

    transmitComplete(obj)
    square:setSquareChanged()
end

BWOABuildTools.Skeleton = function (x, y, z)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local spriteName = "location_shop_mall_01_68"
	local obj = IsoMannequin.new(getCell(), nil, getSprite(spriteName))
	obj:setMannequinScriptName("MannequinSkeleton01")
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
end

local container = function(x, y, z, spriteName, data)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoObject.new(square, spriteName, "")
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()
end

BWOABuildTools.SmallTableN = function(x, y, z, data)
    local sprite = "furniture_storage_01_52"
    container(x, y, z, sprite, data)
end

BWOABuildTools.SmallTableS = function(x, y, z, data)
    local sprite = "furniture_storage_01_55"
    container(x, y, z, sprite, data)
end

local lamp = function(x, y, z, spriteName, data)
    local cell = getCell()
    local square = cell:getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end

    local sprite = getSprite(spriteName)
    local spriteProps = sprite:getProperties()
    spriteProps:set("lightR", tostring(data.r))
    spriteProps:set("lightG", tostring(data.g))
    spriteProps:set("lightB", tostring(data.b))
    spriteProps:set("LightRadius",tostring(data.d))

    if spriteProps:has(IsoPropertyType.STREETLIGHT) then
        spriteProps:unset("streetlight")
    end

    local ls = IsoLightSwitch.new(cell, square, sprite, square:getRoomID())
    if data.battery then
        -- A modifiable light switch is added to the dedicated server's static
        -- updater list.  These bunker lights use an artificial permanent
        -- battery, so that updater only drains/synchronizes a device that the
        -- player must never service.  Worse, B42 can retain it after its
        -- square object is replaced and then emits SyncIsoObject index -1 once
        -- per game minute.  Keep the visual battery state but do not register
        -- the server-side decorative lamp as modifiable.
        ls:setCanBeModified(not isServer())
        ls:setPower(1000)
        ls:setHasBattery(true)
        ls:setUseBatteryDirect(true)
    else
        ls:setUseBattery(false)
    end

    if data.nobulb then
        ls:removeLightBulb(getCell():getFakeZombieForHit())
    end
    ls:addLightSourceFromSprite()
    ls:setPrimaryR(data.r / 255)
    ls:setPrimaryG(data.g / 255)
    ls:setPrimaryB(data.b / 255)
    square:AddSpecialObject(ls)
    transmitComplete(ls)
    if data.active == nil or data.active == true then
        ls:setActive(true)
    else
        ls:setActive(false)
    end
    square:setSquareChanged()

end

BWOABuildTools.WallPanel = function(x, y, z)
    local data = {r = 40, g = 0, b = 0, d=1, active=true, battery=true}
    lamp(x, y, z, "theark_01_14", data)
end

BWOABuildTools.WallPanelOn = function(x, y, z)
    local data = {r = 0, g = 40, b = 0, d=1, active=true, battery=true}
    lamp(x, y, z, "theark_01_15", data)
end

BWOABuildTools.DoorLight = function(x, y, z)
    local data = {r = 70, g = 0, b = 0, d=2, active=true, battery=true}
    local sprite = "location_entertainment_theatre_01_136"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.DoorLightOn = function(x, y, z)
    local data = {r = 0, g = 70, b = 0, d=2, active=true, battery=true}
    local sprite = "location_entertainment_theatre_01_208"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.LampBatteryWeak = function(x, y, z, spriteName)
    local data = {r = 40, g = 40, b = 255, d=4, active=true, battery=true}
    lamp(x, y, z, spriteName, data)
end

BWOABuildTools.LampBattery = function(x, y, z, spriteName)
    local data = {r = 255, g = 240, b = 88, d=4, active=true, battery=true}
    lamp(x, y, z, spriteName, data)
end

BWOABuildTools.EmergencyExitN = function(x, y, z)
    local data = {r = 70, g = 0, b = 0, d=2, active=false, battery=true}
    local sprite = "lighting_indoor_01_25"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.EmergencyExitW = function(x, y, z)
    local data = {r = 70, g = 0, b = 0, d=2, active=false, battery=true}
    local sprite = "lighting_indoor_01_24"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.EmergencyLightN = function(x, y, z)
    local data = {r = 70, g = 0, b = 0, d=2, active=false, battery=true}
    local sprite = "location_entertainment_theatre_01_138"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.EmergencyLightW = function(x, y, z)
    local data = {r = 70, g = 0, b = 0, d=2, active=false, battery=true}
    local sprite = "location_entertainment_theatre_01_136"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.EmergencyLightS = function(x, y, z)
    local data = {r = 70, g = 0, b = 0, d=2, active=false, battery=true}
    local sprite = "location_entertainment_theatre_01_142"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.EmergencyLightE = function(x, y, z)
    local data = {r = 70, g = 0, b = 0, d=2, active=false, battery=true}
    local sprite = "location_entertainment_theatre_01_140"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.LampOvalN = function(x, y, z)
    local data = {r = 255, g = 240, b = 88, d=4}
    local sprite = "lighting_outdoor_01_40"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.LampOvalW = function(x, y, z)
    local data = {r = 255, g = 240, b = 88, d=4}
    local sprite = "lighting_outdoor_01_41"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.LampOvalS = function(x, y, z)
    local data = {r = 255, g = 240, b = 88, d=4}
    local sprite = "lighting_outdoor_01_44"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.LampOvalE = function(x, y, z)
    local data = {r = 255, g = 240, b = 88, d=4}
    local sprite = "lighting_outdoor_01_45"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.LampDeskYellowN = function(x, y, z)
    local data = {r = 255, g = 240, b = 180, d=2}
    local sprite = "lighting_indoor_02_14"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.LampDeskYellowW = function(x, y, z)
    local data = {r = 255, g = 240, b = 180, d=2}
    local sprite = "lighting_indoor_02_13"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.LampDeskYellowS = function(x, y, z)
    local data = {r = 255, g = 240, b = 180, d=2}
    local sprite = "lighting_indoor_02_12"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.LampDeskYellowE = function(x, y, z)
    local data = {r = 255, g = 240, b = 180, d=2}
    local sprite = "lighting_indoor_02_15"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.LampCeilingNS = function(x, y, z)
    local data = {r = 255, g = 240, b = 180, d=7}
    local sprite = "lighting_indoor_03_21"
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.LampCustom = function(x, y, z, sprite, data)
    if not data then
         data = {r = 255, g = 240, b = 180, d=7}
    end
    lamp(x, y, z, sprite, data)
end

BWOABuildTools.TV = function(x, y, z, spriteName, data)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoTelevision.new(getCell(), square, getSprite(spriteName))
    obj:getDeviceData():getDevicePresets():clearPresets()
    
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    square:setSquareChanged()

    if data and data.active then
        local dd = obj:getDeviceData()
        if not dd then return true end

        if not dd:getIsTurnedOn() then
            dd:setIsTurnedOn(true)
        end
    end
end


BWOABuildTools.FarmPlot = function(x, y, z, seedType)
    local square = getCell():getOrCreateGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local obj = IsoObject.new(square, "blends_natural_01_64", "")
    square:AddSpecialObject(obj)
    transmitComplete(obj)
    SFarmingSystem.instance:plow(square)
    local plant = SFarmingSystem.instance:getLuaObjectAt(square:getX(), square:getY(), square:getZ())
    
    if plant then 
        plant.waterLvl = 100
        if plant.state == "plow" then
            plant:seed(seedType, 0)
            plant.health = 100
        end
        SFarmingSystem.instance:growPlant(plant, nil, true)
        SFarmingSystem.instance:growPlant(plant, nil, true)
        SFarmingSystem.instance:growPlant(plant, nil, true)
        SFarmingSystem.instance:growPlant(plant, nil, true)
        -- SFarmingSystem.instance:growPlant(plant, nil, true)
        -- SFarmingSystem.instance:growPlant(plant, nil, true)
    end
end

-- removal

BWOABuildTools.RemoveObject = function(x, y, z, name)
    local square = getCell():getGridSquare(x, y, z)
    if square then
        local objects = square:getObjects()
        for i=0, objects:size()-1 do
            local object = objects:get(i)
            local sprite = object:getSprite()
            if sprite then
                local spriteName = sprite:getName()
                local props = sprite:getProperties()
                if name == spriteName or (props:has("CustomName") and props:get("CustomName") == name) then
                    square:transmitRemoveItemFromSquare(object)
                    break
                end
            end
        end
    end
end

-- batch building

BWOABuildTools.ELS = function(tab)
    for _, el in pairs(tab) do
        if el.dir == "N" then
            BWOABuildTools.EmergencyLightN(el.x, el.y, el.z)
        elseif el.dir == "W" then
            BWOABuildTools.EmergencyLightW(el.x, el.y, el.z)
        elseif el.dir == "S" then
            BWOABuildTools.EmergencyLightS(el.x, el.y, el.z)
        elseif el.dir == "E" then
            BWOABuildTools.EmergencyLightE(el.x, el.y, el.z)
        elseif el.dir == "XW" then
            BWOABuildTools.EmergencyExitW(el.x, el.y, el.z)
        elseif el.dir == "XN" then
            BWOABuildTools.EmergencyExitN(el.x, el.y, el.z)
        end
    end
end


BWOABuildTools.ClearAll = function(x, y, z)
    local cell = getCell()
    local square = cell:getGridSquare(x, y, z)
    if not square then return end
    local objects = square:getObjects()
    for i = objects:size()-1, 0, -1 do
        local object = objects:get(i)
        square:transmitRemoveItemFromSquare(object)
    end
    square:setSquareChanged()
end

BWOABuildTools.ClearVegetation = function(x, y, z)
    local cell = getCell()
    local square = cell:getGridSquare(x, y, z)
    if not square or not square:getChunk() then return end
    local objects = square:getObjects()
    for i = objects:size()-1, 0, -1 do
        local object = objects:get(i)
        local sprite = object:getSprite()
        if sprite then
            local props = sprite:getProperties()
            if props:has(IsoFlagType.canBeRemoved) then
                square:transmitRemoveItemFromSquare(object)
            end
        end
    end
    -- square:setSquareChanged()
end

-- blueprint builder for lava lakes
BWOABuildTools.LavaLake = function(x, y, blueprint)
    local cell = getCell()


    for _, el in pairs(blueprint) do
        BWOABuildTools.ClearVegetation(x + el.x, y + el.y, 0)
        BWOABuildTools.Generic(x + el.x, y + el.y, 0, el.sprite)
        local heatsource = IsoHeatSource.new(x + el.x, y + el.y, 0, 7, 200)
        cell:addHeatSource(heatsource)

        if math.abs(el.x) % 10 == 0 and math.abs(el.y) % 10 == 0 then
            local square = cell:getOrCreateGridSquare(x + el.x, y + el.y, -2)
            if square and square:getChunk() then
                local genItem = BanditCompatibility.InstanceItem("Base.Generator_Old")
                local generator = IsoGenerator.new(genItem, cell, square)
                generator:transmitCompleteItemToClients()
                generator:setCondition(100)
                generator:setFuel(100)
                generator:setConnected(true)
                generator:setActivated(true)
                cell:addToProcessIsoObjectRemove(generator)
                square:setSquareChanged()
            end
        end


    end


end

-- advanced builder
BWOABuildTools.BuildMap = function(x, y, z, map, dict)
    local cursor = {x = 0, y = 0}
    for i = 1, #map do
        local char = map:sub(i, i)
        
        local obj = dict[char]
        if obj then
            local builder = "Generic"
            if obj.builder then
                builder = obj.builder
            end
            BWOABuildTools[builder](x + cursor.x, y + cursor.y, z, obj.sprite)
        end

        cursor.x = cursor.x + 1

        if char == "\n" then
            cursor.x = 0
            cursor.y = cursor.y + 1
        end
    end
end

-- Remove every exact sprite match.  This is used only to recover an
-- interrupted room build: the original builders are not transactional and
-- may have added the same early objects many times before throwing an error.
BWOABuildTools.RemoveObjectsBySprite = function(x, y, z, spriteName)
    local square = getCell():getGridSquare(x, y, z)
    if not square then return 0 end

    local removed = 0
    local objects = square:getObjects()
    for i = objects:size() - 1, 0, -1 do
        local object = objects:get(i)
        local sprite = object and object:getSprite() or nil
        if sprite and sprite:getName() == spriteName then
            square:transmitRemoveItemFromSquare(object)
            removed = removed + 1
        end
    end
    if removed > 0 then square:setSquareChanged() end
    return removed
end
