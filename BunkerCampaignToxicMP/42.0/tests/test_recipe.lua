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
    local usedDelta = percent
    if percent ~= nil then md.percent = percent end
    return {
        getFullType = function(self) return fullType end,
        getType = function(self) return itemType end,
        getModData = function(self) return md end,
        getConditionMax = function(self) return 10 end,
        getCondition = function(self) return condition end,
        setCondition = function(self, value) condition = value end,
        getUsedDelta = fullType == "Base.GasmaskFilter" and function(self) return usedDelta end or nil,
        setUsedDelta = fullType == "Base.GasmaskFilter" and function(self, value) usedDelta = value end or nil,
        syncItemFields = function(self) self.synced = true end,
        testCondition = function(self) return condition end,
        testUsedDelta = function(self) return usedDelta end,
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
local returnedFilter = item("Base.GasmaskFilter")
BunkerCampaignToxicMP.OnCreateFilterRecipe(data({usedMask}, {emptyMask, returnedFilter}))
assert(returnedFilter:testUsedDelta() == 0.37, "removal must preserve vanilla Remaining charge")
assert(returnedFilter:getModData().percent == nil, "vanilla filters must not get a second custom charge field")
assert(returnedFilter.synced == true, "changed filter must be synchronized")
assert(emptyMask:getModData().percent == nil, "empty mask must not receive filter charge")

local inputFilter = item("Base.GasmaskFilter", 0.42)
local filteredMask = item("Base.PPM88")
BunkerCampaignToxicMP.OnCreateFilterRecipe(data({item("Base.PPM88NoFilter"), inputFilter}, {filteredMask}))
assert(filteredMask:getModData().percent == 0.42, "insertion must transfer filter charge to mask")
assert(filteredMask:testCondition() == 4, "filtered mask condition must reflect its charge")
assert(filteredMask.synced == true, "changed mask must be synchronized")

print("BunkerCampaignToxicMP recipe tests passed")
