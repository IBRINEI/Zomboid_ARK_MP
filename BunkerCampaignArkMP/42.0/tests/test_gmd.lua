InitBWOAModData(true)
local state = GetBWOAModData()
assert(type(state) == "table", "Ark compatibility state must be a table")
assert(type(state.permanentNPC) == "table", "permanentNPC must always be initialized as a table")
assert(type(state.ventilation) == "table", "ventilation state must exist")
assert(type(state.airintakes) == "table" and #state.airintakes == 4, "air intake defaults must exist")

state.permanentNPC = "corrupt-single-player-value"
InitBWOAModData(false)
assert(type(GetBWOAModData().permanentNPC) == "table", "invalid permanentNPC must be repaired")

ArkMPTestSetClient(true)
LoadBWOAModData("BanditWeekOneTheArk", { permanentNPC=false, ventilation=false })
local clientState = GetBWOAModData()
assert(type(clientState.permanentNPC) == "table", "received client state must be sanitized")
assert(type(clientState.ventilation) == "table", "received ventilation must be sanitized")

print("BunkerCampaignArkMP GMD tests passed")
