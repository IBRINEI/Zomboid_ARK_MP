assert(type(ISRadioactiveWashBegin) == "table"
    and type(ISRadioactiveWashBegin.new) == "function",
    "shared begin action constructor must be visible to the MP server")
assert(type(ISRadioactiveWashFinalize) == "table"
    and type(ISRadioactiveWashFinalize.new) == "function",
    "shared finalize action constructor must be visible to the MP server")
assert(type(ISBunkerManualWash) == "table"
    and type(ISBunkerManualWash.new) == "function",
    "shared bunker wash constructor must be visible to the MP server")

local character = {}
local beginAction = ISRadioactiveWashBegin:new(character, nil, "body", nil)
local finalizeAction = ISRadioactiveWashFinalize:new(character, nil, "body", nil)
local bunkerAction = ISBunkerManualWash:new(character, "body", nil, 10)

assert(beginAction.character == character and beginAction.maxTime == 1,
    "begin action must be constructible in the shared environment")
assert(finalizeAction.character == character and finalizeAction.maxTime == 1,
    "finalize action must be constructible in the shared environment")
assert(bunkerAction.character == character and bunkerAction.maxTime >= 1,
    "bunker wash action must be constructible in the shared environment")

print("BunkerCampaign shared manual wash action tests passed")
