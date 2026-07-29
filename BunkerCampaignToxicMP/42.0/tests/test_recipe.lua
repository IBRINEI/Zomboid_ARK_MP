local function list(values)
    return {
        size = function(self) return #values end,
        get = function(self, index) return values[index + 1] end,
    }
end

local function item(fullType, percent)
    local itemType = string.match(fullType, "%.(.+)$")
    local md = {}
    local condition = 10
    if percent ~= nil then md.percent = percent end
    return {
        getFullType = function(self) return fullType end,
        getType = function(self) return itemType end,
        getModData = function(self) return md end,
        getConditionMax = function(self) return 10 end,
        getCondition = function(self) return condition end,
        setCondition = function(self, value) condition = value end,
        syncItemFields = function(self) self.synced = true end,
        testCondition = function(self) return condition end,
    }
end

local function data(consumed, created)
    return {
        getAllDestroyInputItems = function(self) return list(consumed) end,
        getAllRecordedConsumedItems = function(self) return list(consumed) end,
        getAllCreatedItems = function(self) return list(created) end,
    }
end

local usedMask = item("Base.PPM88", 0.37)
local emptyMask = item("Base.PPM88NoFilter")
local returnedFilter = item("Base.GasMaskFilter")
BunkerCampaignToxicMP.OnCreateFilterRecipe(data({usedMask}, {emptyMask, returnedFilter}))
assert(returnedFilter:getModData().percent == 0.37, "removal must preserve remaining filter charge")
assert(returnedFilter:testCondition() == 3, "removed filter condition must reflect its charge")
assert(returnedFilter.synced == true, "changed filter must be synchronized")
assert(emptyMask:getModData().percent == nil, "empty mask must not receive filter charge")

local inputFilter = item("Base.GasMaskFilter", 0.42)
local filteredMask = item("Base.PPM88")
BunkerCampaignToxicMP.OnCreateFilterRecipe(data({item("Base.PPM88NoFilter"), inputFilter}, {filteredMask}))
assert(filteredMask:getModData().percent == 0.42, "insertion must transfer filter charge to mask")
assert(filteredMask:testCondition() == 4, "filtered mask condition must reflect its charge")
assert(filteredMask.synced == true, "changed mask must be synchronized")

print("BunkerCampaignToxicMP recipe tests passed")
