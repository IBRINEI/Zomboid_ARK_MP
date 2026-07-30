if isClient() then return end

require "BunkerCampaign/CampaignState"
require "BunkerCampaignIntegration/Constants"
require "BunkerCampaignIntegration/WaterpipesAdapter"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local CampaignState = BunkerCampaign.CampaignState
local Constants = BunkerCampaignIntegration.Constants
local Adapter = BunkerCampaignIntegration.WaterpipesAdapter
local WaterService = { data=nil }

local function prepare()
    local integration = ModData.getOrCreate(Constants.STATE_KEY)
    if type(integration.waterService) ~= "table" then integration.waterService = {} end
    local data = integration.waterService
    if type(data.transactions) ~= "table" then data.transactions = {} end
    if type(data.transactionOrder) ~= "table" then data.transactionOrder = {} end
    data.nextTransactionId = math.max(1, math.floor(tonumber(data.nextTransactionId) or 1))
    WaterService.data = data
    return data
end

local function waterData()
    if not WaterService.data then prepare() end
    return ModData.getOrCreate(Constants.WATERPIPES_STATE_KEY)
end

local function remember(id, result)
    local data = WaterService.data or prepare()
    data.transactions[id] = result
    data.transactionOrder[#data.transactionOrder + 1] = id
    while #data.transactionOrder > BunkerCampaign.Constants.WATER.MAX_TRANSACTION_HISTORY do
        local expired = table.remove(data.transactionOrder, 1)
        data.transactions[expired] = nil
    end
end

local function transactionId(consumerId, supplied)
    if type(supplied) == "string" and supplied ~= "" then return supplied end
    local data = WaterService.data or prepare()
    local id = tostring(consumerId or "water") .. ":" .. tostring(data.nextTransactionId)
    data.nextTransactionId = data.nextTransactionId + 1
    return id
end

function WaterService.available(quality)
    return Adapter.availableBunkerWater(waterData(), quality ~= "tainted")
end

function WaterService.consume(liters, quality, consumerId, suppliedId)
    liters = tonumber(liters) or 0
    if liters <= 0 then return false, "invalid_water_amount" end
    local id = transactionId(consumerId, suppliedId)
    local existing = (WaterService.data or prepare()).transactions[id]
    if existing then return existing.ok, existing.code, existing.liters, id end

    local cleanOnly = quality ~= "tainted"
    local ok, consumed = Adapter.consumeBunkerWater(waterData(), liters, cleanOnly)
    local result = {
        ok=ok == true,
        code=ok and "consumed" or (cleanOnly and "clean_water_required" or "water_required"),
        liters=consumed or 0,
        consumerId=tostring(consumerId or "unknown"),
    }
    remember(id, result)
    if ok then
        local campaign = CampaignState.get()
        local water = campaign and campaign.bunker.modules.water
        if water then
            water.telemetry.consumedLiters = (water.telemetry.consumedLiters or 0) + consumed
            water.telemetry.lastTransactionId = id
        end
        if type(TransmitWPModData) == "function" then TransmitWPModData() end
        CampaignState.setWaterSnapshot(Adapter.sample(waterData()), "water service")
    end
    return result.ok, result.code, result.liters, id
end

function WaterService.fillForQa()
    local changed = Adapter.fillBunkerWater(waterData())
    if changed and type(TransmitWPModData) == "function" then TransmitWPModData() end
    CampaignState.setWaterSnapshot(Adapter.sample(waterData()), "QA water fill")
    return changed
end

function WaterService.sample()
    return Adapter.sample(waterData())
end

Events.OnInitGlobalModData.Add(prepare)

BunkerCampaignIntegration.WaterService = WaterService
return WaterService
