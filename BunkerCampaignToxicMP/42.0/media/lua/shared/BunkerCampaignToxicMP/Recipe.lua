require "BunkerCampaignToxicMP/Constants"

BunkerCampaignToxicMP = BunkerCampaignToxicMP or {}

local function eachJavaList(list, fn)
    if not list then return end
    for index = 0, list:size() - 1 do fn(list:get(index)) end
end

local function remaining(item)
    if not item then return nil end
    if type(item.getUsedDelta) == "function" then
        local value = tonumber(item:getUsedDelta())
        if value ~= nil then return math.max(0, math.min(1, value)) end
    end
    local md = item:getModData()
    local value = tonumber(md and md.percent)
    if not value and type(item.getConditionMax) == "function" and type(item.getCondition) == "function" then
        local maximum = tonumber(item:getConditionMax()) or 0
        if maximum > 0 then value = (tonumber(item:getCondition()) or maximum) / maximum end
    end
    if not value then return 1 end
    return math.max(0, math.min(1, value))
end

local function applyCharge(item, charge)
    local fullType = item:getFullType()
    if fullType == "Base.GasmaskFilter" and type(item.setUsedDelta) == "function" then
        item:setUsedDelta(charge)
        item:getModData().percent = nil
        return
    end
    item:getModData().percent = charge
    if type(item.getConditionMax) == "function" and type(item.setCondition) == "function" then
        local maximum = tonumber(item:getConditionMax()) or 0
        if maximum > 0 then
            local condition = charge <= 0 and 0 or math.max(1, math.floor(maximum * charge))
            item:setCondition(condition)
        end
    end
end

-- B42 craftRecipe OnCreate callbacks receive (CraftRecipeData, character).
-- Keep compatibility with the table-shaped test/early prototype argument so
-- old saves cannot fail if another copied recipe still uses that wrapper.
function BunkerCampaignToxicMP.OnCreateFilterRecipe(data, character)
    if type(data) == "table" and data.craftRecipeData then
        character = character or data.character
        data = data.craftRecipeData
    end
    if not data then return end

    local charge = nil

    local consumed = nil
    if data.getAllDestroyInputItems then
        consumed = data:getAllDestroyInputItems()
    elseif data.getAllRecordedConsumedItems then
        consumed = data:getAllRecordedConsumedItems()
    end

    eachJavaList(consumed, function(item)
        if not item then return end
        local fullType = item:getFullType()
        local md = item:getModData()
        if fullType == "Base.GasmaskFilter" or fullType == "Base.GasMaskFilter"
            or (md and md.percent ~= nil) then
            charge = remaining(item)
        end
    end)
    if charge == nil then charge = 1 end

    eachJavaList(data:getAllCreatedItems(), function(item)
        if not item then return end
        local fullType = item:getFullType()
        if fullType == "Base.GasmaskFilter" or fullType == "Base.GasMaskFilter"
            or BunkerCampaignToxicMP.Constants.PROTECTIVE_MASKS[item:getType()] then
            applyCharge(item, charge)
            if character and type(syncItemModData) == "function" then
                pcall(syncItemModData, character, item)
            end
            if item.syncItemFields then item:syncItemFields() end
        end
    end)
end

return BunkerCampaignToxicMP
