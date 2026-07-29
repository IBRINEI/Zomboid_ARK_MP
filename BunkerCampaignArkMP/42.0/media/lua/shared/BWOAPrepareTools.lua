BWOAPrepareTools = BWOAPrepareTools or {}

BWOAPrepareTools.GetSurfaceOffset = function(x, y, z)

    local cell = getCell()
    local square = cell:getGridSquare(x, y, z)
    local tileObjects = square:getLuaTileObjectList()
    local squareSurfaceOffset = 0

    -- get the object with the highest offset
    for k, object in pairs(tileObjects) do
        local surfaceOffsetNoTable = object:getSurfaceOffsetNoTable()
        if surfaceOffsetNoTable > squareSurfaceOffset then
            squareSurfaceOffset = surfaceOffsetNoTable
        end

        local surfaceOffset = object:getSurfaceOffset()
        if surfaceOffset > squareSurfaceOffset then
            squareSurfaceOffset = surfaceOffset
        end
    end

    return squareSurfaceOffset / 96
end

BWOAPrepareTools.BloodSplat = function(x, y, z)
    local cell = getCell()
    local square = cell:getOrCreateGridSquare(x, y, z)
    if square then
        square:splatBlood(2, 1)    
    end
end

BWOAPrepareTools.DarkenLight = function(x, y, z)
    local cell = getCell()
    local square = cell:getOrCreateGridSquare(x, y, z)
    local objects = square:getObjects()
    for i=0, objects:size()-1 do
        local object = objects:get(i)
        if instanceof(object, "IsoLightSwitch") then
            local sprite = object:getSprite()
            local props = sprite:getProperties()
            if props:has("CustomName") then
                customName = props:get("CustomName")
                if customName == "Switch" then
                    object:setActive(false)
                    -- Removing a map-authored light switch changes the square's
                    -- network-object indexes.  The original SP mod could do
                    -- this locally; in MP it leaves clients with a phantom
                    -- switch and breaks ISToggleLightAction on the server.
                    if isServer() and IsoObjectChange then
                        object:sendObjectChange(IsoObjectChange.STATE)
                    end
                end

            end
        end
    end
end

local addWorldItem = function(x, y, z, item, data)
    local cell = getCell()
    local square = cell:getOrCreateGridSquare(x, y, z)
    
    if not data then data = {} end
    if not data.x then data.x = 0.5 end
    if not data.y then data.y = 0.5 end
    if not data.z then data.z = 0 end

    item = square:AddWorldInventoryItem(item, data.x, data.y, data.z)

    if data.rx then
        item:setWorldXRotation(data.rx)
    end
    if data.ry then
        item:setWorldYRotation(data.ry)
    end
    if data.rz then
        item:setWorldZRotation(data.rz)
    end
end

BWOAPrepareTools.AddWorldItem = function(x, y, z, itemType, data)
    local item = BanditCompatibility.InstanceItem(itemType)
    if item then
        addWorldItem(x, y, z, item, data)
    else
        print ("ERROR: problem with item: " .. itemType)
    end
end 

BWOAPrepareTools.AddWorldItemSpecial = function(x, y, z, item, data)
    addWorldItem(x, y, z, item, data)
end 

BWOAPrepareTools.AddItemsToContainer = function(x, y, z, items, customName, preserveCurrent)
    local square = getCell():getGridSquare(x, y, z)
    local container
    if square then
        local objects = square:getObjects()
        for i=0, objects:size()-1 do
            local object = objects:get(i)                
            local sprite = object:getSprite()
            if sprite then
                local props = sprite:getProperties()
                if props:has("CustomName") then
                    local cn = props:get("CustomName")
                    if cn == customName then
                        container = object:getContainer()
                    end
                end
            end
        end
    end

    if container then
        if not preserveCurrent then
            container:clear()
        end
        if items[1] then
            for _, item in ipairs(items) do
                local item2 = container:AddItem(item)
            end
        else
            for itemType, itemCnt in pairs(items) do
                for i=1, itemCnt do
                    local item = container:AddItem(itemType)
                end 
            end
        end
        if not isClient() then
            -- if container:getParent() and container:getParent():getOverlaySprite() then
                ItemPicker.updateOverlaySprite(container:getParent())
            -- end
        end
        container:setDrawDirty(true)
    end
end

BWOAPrepareTools.AddAnimalCorpse = function(x, y, z, animalType, race, size)
    -- "boar", "landrace", 1
    local square = getCell():getGridSquare(x, y, z)
    local animal = IsoAnimal.new(getCell(), square:getX(), square:getY(), square:getZ(), animalType, race)
    if animal then
        animal:getData():setSizeForced(size)
        local corpse = IsoDeadBody.new(animal, false)
        if corpse then
            square:addCorpse(corpse, false)
            corpse:invalidateCorpse()
            corpse:setInvalidateNextRender(true)
            animal:remove()
            corpse:setForwardDirectionAngle(0)
            corpse:setX(x)
            corpse:setY(y)
            corpse:setZ(z)
            sendCorpse(corpse)
        end
    end
end

BWOAPrepareTools.AddHumanCorpse = function(x, y, z, outfits, femaleChance)
    local fakeItem = BanditCompatibility.InstanceItem("Base.AssaultRifle")
    local fakeZombie = getCell():getFakeZombieForHit()
    local outfit = BanditUtils.Choice(outfits)
    local zombieList = BanditCompatibility.AddZombiesInOutfit(x, y, z, outfit, femaleChance, false, false, false, false, false, false, 2)
    for i=0, zombieList:size()-1 do
        -- print ("place body at x:" .. x .. " y:" .. y)
        local zombie = zombieList:get(i)
        local banditVisuals = zombie:getHumanVisual()
        local id = BanditUtils.GetCharacterID(zombie)
        local r = 1 + math.abs(id) % 5 
        if zombie:isFemale() then
            banditVisuals:setSkinTextureName("FemaleBody0" .. tostring(r))
        else
            banditVisuals:setSkinTextureName("MaleBody0" .. tostring(r))
        end

        -- zombie:setForceFakeDead(true)
        BanditCompatibility.Splash(zombie, fakeItem, fakeZombie)

        zombie:getInventory():clear()
        zombie:Hit(fakeItem, fakeZombie, 50, false, 1, false)
        
    end
end

BWOAPrepareTools.AddHumanCorpseDetail = function(x, y, z, female, clothing, items)
    local fakeItem = BanditCompatibility.InstanceItem("Base.AssaultRifle")
    local fakeZombie = getCell():getFakeZombieForHit()
    local bandit = createZombie(x, y, z, nil, 0, IsoDirections.getRandom())
    local id = BanditUtils.GetCharacterID(bandit)
    local r = 1 + math.abs(id) % 5 
    bandit:setFemale(female)
    BanditCompatibility.Splash(bandit, fakeItem, fakeZombie)

    local hv = bandit:getHumanVisual()
    if female then
        hv:setSkinTextureName("FemaleBody0" .. tostring(r))
    else
        hv:setSkinTextureName("MaleBody0" .. tostring(r))
    end
    hv:setSkinTextureName("MaleBody01")

    --[[
    local maxIndex = BloodBodyPartType.MAX:index()
    for i = 0, maxIndex - 1 do
        local part = BloodBodyPartType.FromIndex(i)
        hv:setBlood(part, 1)
        hv:setDirt(part, 1)
    end
    ]]
    
    local body = IsoDeadBody.new(bandit, false)
    body:setForwardDirectionAngle(math.pi / 2)
    body:setX(x)
    body:setY(y)
    body:setZ(z)
    sendCorpse(body)

    local wornItems = body:getWornItems()
    local inventory = body:getContainer()

    -- for _, bodyLocationDef in pairs(BanditUtils.GetBodyLocationsOrdered()) do
        for _, clothingData in ipairs(clothing) do
            local bodyLocation = clothingData.bl
            local itemType = clothingData.itemType
            -- if bodyLocation == bodyLocationDef then
                local item = BanditCompatibility.InstanceItem(itemType)
                if item then
                    wornItems:setItem(bodyLocation, item)
                    inventory:AddItem(item)
                end
            -- end
        end
    -- end

    for _, itemType in ipairs(items) do
        local item = BanditCompatibility.InstanceItem(itemType)
        if item then
            inventory:AddItem(item)
        end
    end

    
    -- getCell():getGridSquare(x, y, z):getChunk():addBloodSplat(x, y, z, 20)

    bandit:removeFromSquare()
    bandit:removeFromWorld()
end

BWOAPrepareTools.AddVehicle = function(x, y, z, vtype, data)
    local cell = getCell()
    local square = getCell():getGridSquare(x, y, z)
    if not square then return end

    if not square:getChunk() then return end

    if not data then data = {} end
    if not data.dir then data.dir = IsoDirections.E end

    local vehicle = addVehicle(vtype, square:getX(), square:getY(), square:getZ())
    if not vehicle then return end

    for i = 0, vehicle:getPartCount() - 1 do
        local container = vehicle:getPartByIndex(i):getItemContainer()
        if container then
            container:removeAllItems()
        end
    end

    if not data.condition then data.condition = 100 end
    vehicle:setGeneralPartCondition(data.condition / 100, 0)

    if not data.fuel then data.fuel = 100 end
    local gasTank = vehicle:getPartById("GasTank")
    if gasTank then
        local fuel = gasTank:getContainerCapacity() * data.fuel / 100
        gasTank:setContainerContentAmount(fuel)
    end

    vehicle:setRust(100)

    return vehicle
end
