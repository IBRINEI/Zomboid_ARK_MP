require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "BunkerCampaign/ClientState"

BunkerCampaign = BunkerCampaign or {}

local ClientState = BunkerCampaign.ClientState
local VentilationPanel = ISCollapsableWindow:derive("BunkerCampaignVentilationPanel")
VentilationPanel.instance = nil

local function percent(value)
    return string.format("%.1f%%", (tonumber(value) or 0) * 100)
end

local function number(value, decimals)
    return string.format("%." .. tostring(decimals or 0) .. "f", tonumber(value) or 0)
end

local function canControl()
    if not isClient() then return true end
    local player = getPlayer()
    if not player then return false end
    local bounds = BunkerCampaign.Constants.BUNKER_CONTROL_BOUNDS
    local z = math.floor(player:getZ())
    return player:getX() >= bounds.x1 and player:getX() <= bounds.x2
        and player:getY() >= bounds.y1 and player:getY() <= bounds.y2
        and bounds.levels[z] == true
end

function VentilationPanel:createChildren()
    ISCollapsableWindow.createChildren(self)

    local firstY = self.height - 158
    local secondY = self.height - 128
    local thirdY = self.height - 98
    local fourthY = self.height - 68
    local fifthY = self.height - 38
    self.mainButton = ISButton:new(12, firstY, 155, 26, getText("UI_BC_MainGenerator"), self, VentilationPanel.onToggleMain)
    self.mainButton:initialise()
    self.mainButton:instantiate()
    self:addChild(self.mainButton)

    self.backupButton = ISButton:new(172, firstY, 155, 26, getText("UI_BC_BackupGenerator"), self, VentilationPanel.onToggleBackup)
    self.backupButton:initialise()
    self.backupButton:instantiate()
    self:addChild(self.backupButton)

    self.refreshButton = ISButton:new(332, firstY, 156, 26, getText("UI_BC_Refresh"), self, VentilationPanel.onRefresh)
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self:addChild(self.refreshButton)

    self.lightingButton = ISButton:new(12, secondY, 476, 26, getText("UI_BC_MainLighting"), self, VentilationPanel.onToggleLighting)
    self.lightingButton:initialise()
    self.lightingButton:instantiate()
    self:addChild(self.lightingButton)

    self.modeButton = ISButton:new(12, thirdY, 235, 26, getText("UI_BC_VentilationMode"), self, VentilationPanel.onCycleMode)
    self.modeButton:initialise()
    self.modeButton:instantiate()
    self:addChild(self.modeButton)

    self.waterButton = ISButton:new(252, thirdY, 236, 26, getText("UI_BC_WaterPump"), self, VentilationPanel.onToggleWater)
    self.waterButton:initialise()
    self.waterButton:instantiate()
    self:addChild(self.waterButton)

    self.purgeButton = ISButton:new(12, fourthY, 155, 26, getText("UI_BC_AirlockPurge"), self, VentilationPanel.onPurge)
    self.purgeButton:initialise()
    self.purgeButton:instantiate()
    self:addChild(self.purgeButton)

    self.filterButton = ISButton:new(172, fourthY, 155, 26, getText("UI_BC_ReplaceAirFilter"), self, VentilationPanel.onReplaceFilter)
    self.filterButton:initialise()
    self.filterButton:instantiate()
    self:addChild(self.filterButton)

    self.bypassButton = ISButton:new(332, fourthY, 156, 26, getText("UI_BC_WaterBypass"), self, VentilationPanel.onToggleBypass)
    self.bypassButton:initialise()
    self.bypassButton:instantiate()
    self:addChild(self.bypassButton)

    self.sourceButton = ISButton:new(12, fifthY, 476, 26, getText("UI_BC_SelectWaterSource"), self, VentilationPanel.onCycleWaterSource)
    self.sourceButton:initialise()
    self.sourceButton:instantiate()
    self:addChild(self.sourceButton)
end

local function toggleGenerator(self, id)
    local power = ClientState.snapshot and ClientState.snapshot.power
    local generator = power and power.generators and power.generators[id]
    if generator and canControl() then
        ClientState.setGeneratorRequested(getSpecificPlayer(self.playerNum), id, not generator.requested)
    end
end

function VentilationPanel:onToggleMain() toggleGenerator(self, "main") end
function VentilationPanel:onToggleBackup() toggleGenerator(self, "backup") end

function VentilationPanel:onToggleLighting()
    local power = ClientState.snapshot and ClientState.snapshot.power
    local consumer = power and power.consumers and power.consumers.main_lighting
    if consumer and canControl() then
        ClientState.setConsumerRequested(getSpecificPlayer(self.playerNum), "main_lighting", not consumer.requested)
    end
end

function VentilationPanel:onCycleMode()
    local snapshot = ClientState.snapshot
    if not snapshot or not snapshot.ventilation or not canControl() then return end
    local current = snapshot.ventilation.requestedMode or "off"
    local modes = { "external_filtration", "emergency_ventilation", "sealed", "off" }
    if snapshot.ventilation.recirculationUnlocked then table.insert(modes, 2, "internal_recirculation") end
    local nextMode = modes[1]
    for index, mode in ipairs(modes) do
        if mode == current then nextMode = modes[index % #modes + 1]; break end
    end
    ClientState.setVentilationMode(getSpecificPlayer(self.playerNum), nextMode)
end

function VentilationPanel:onPurge()
    if canControl() then ClientState.startAirlockPurge(getSpecificPlayer(self.playerNum), "decontamination_chamber") end
end

function VentilationPanel:onReplaceFilter()
    if canControl() then ClientState.replaceVentilationFilter(getSpecificPlayer(self.playerNum)) end
end

function VentilationPanel:onToggleBypass()
    local water = ClientState.snapshot and ClientState.snapshot.water
    if water and water.treatment and canControl() then
        ClientState.setWaterBypass(getSpecificPlayer(self.playerNum), not water.treatment.bypass)
    end
end

function VentilationPanel:onToggleWater()
    local power = ClientState.snapshot and ClientState.snapshot.power
    local consumer = power and power.consumers and power.consumers.water
    if consumer and canControl() then
        ClientState.setConsumerRequested(getSpecificPlayer(self.playerNum), "water", not consumer.requested)
    end
end

function VentilationPanel:onCycleWaterSource()
    local water = ClientState.snapshot and ClientState.snapshot.water
    if not water or type(water.sources) ~= "table" or not canControl() then return end
    local preferred = { "underground_well", "external_tank", "collected_water", "portable_supply" }
    local available = {}
    for _, sourceId in ipairs(preferred) do
        local source = water.sources[sourceId]
        if source and source.enabled
            and (source.renewable or (tonumber(source.availableLiters) or 0) > 0) then
            available[#available + 1] = sourceId
        end
    end
    if #available == 0 then return end
    local nextSource = available[1]
    for index, sourceId in ipairs(available) do
        if sourceId == water.selectedSource then
            nextSource = available[index % #available + 1]
            break
        end
    end
    ClientState.setWaterSource(getSpecificPlayer(self.playerNum), nextSource)
end

function VentilationPanel:onRefresh()
    ClientState.request(getSpecificPlayer(self.playerNum))
end

function VentilationPanel:prerender()
    ISCollapsableWindow.prerender(self)
    local snapshot = ClientState.snapshot
    local ventilation = snapshot and snapshot.ventilation or nil
    local power = snapshot and snapshot.power or nil
    local main = power and power.generators and power.generators.main or nil
    local backup = power and power.generators and power.generators.backup or nil
    local waterConsumer = power and power.consumers and power.consumers.water or nil
    local lightingConsumer = power and power.consumers and power.consumers.main_lighting or nil
    if ventilation then self.modeButton:setTitle(getText("UI_BC_VentilationMode") .. ": " .. tostring(ventilation.requestedMode or "off")) end
    if main then self.mainButton:setTitle(main.requested and getText("UI_BC_StopMain") or getText("UI_BC_StartMain")) end
    if backup then self.backupButton:setTitle(backup.requested and getText("UI_BC_StopBackup") or getText("UI_BC_StartBackup")) end
    if waterConsumer then self.waterButton:setTitle(waterConsumer.requested and getText("UI_BC_DisableWater") or getText("UI_BC_EnableWater")) end
    if lightingConsumer then self.lightingButton:setTitle(lightingConsumer.requested and getText("UI_BC_DisableLighting") or getText("UI_BC_EnableLighting")) end
    self.modeButton:setEnable(ventilation ~= nil and canControl())
    self.mainButton:setEnable(main ~= nil and canControl())
    self.backupButton:setEnable(backup ~= nil and canControl())
    self.waterButton:setEnable(waterConsumer ~= nil and canControl())
    self.lightingButton:setEnable(lightingConsumer ~= nil and canControl())
    self.purgeButton:setEnable(ventilation ~= nil and ventilation.airlock ~= nil and not ventilation.airlock.active and canControl())
    self.filterButton:setEnable(ventilation ~= nil and canControl())
    local treatment = ClientState.snapshot and ClientState.snapshot.water and ClientState.snapshot.water.treatment
    if treatment then self.bypassButton:setTitle(treatment.bypass and getText("UI_BC_CloseBypass") or getText("UI_BC_OpenBypass")) end
    self.bypassButton:setEnable(treatment ~= nil and canControl())
    local water = ClientState.snapshot and ClientState.snapshot.water
    local availableSources = 0
    if water and type(water.sources) == "table" then
        for _, source in pairs(water.sources) do
            if source.enabled and (source.renewable or (tonumber(source.availableLiters) or 0) > 0) then
                availableSources = availableSources + 1
            end
        end
        self.sourceButton:setTitle(getText("UI_BC_SelectWaterSource") .. ": "
            .. tostring(water.selectedSource or water.source or "none"))
    end
    self.sourceButton:setEnable(availableSources > 1 and canControl())
end

function VentilationPanel:render()
    ISCollapsableWindow.render(self)
    local x = 14
    local y = self:titleBarHeight() + 12
    local lineHeight = 18
    local snapshot = ClientState.snapshot

    if not snapshot or not snapshot.ventilation then
        self:drawText(getText("UI_BC_WaitingForServer"), x, y, 1, 0.8, 0.3, 1, UIFont.Small)
        return
    end

    local ventilation = snapshot.ventilation
    local function drawRows(rows)
        for _, row in ipairs(rows) do
            self:drawText(row[1] .. ":", x, y, 0.75, 0.80, 0.85, 1, UIFont.Small)
            self:drawText(row[2], 230, y, 1, 1, 1, 1, UIFont.Small)
            y = y + lineHeight
        end
    end

    drawRows({
        { getText("UI_BC_StateRevision"), tostring(snapshot.revision or "-") },
    })
    local power = snapshot.power
    if power then
        self:drawText(getText("UI_BC_PowerSection"), x, y, 0.35, 0.75, 1, 1, UIFont.Small)
        y = y + lineHeight
        local main = power.generators and power.generators.main or {}
        local backup = power.generators and power.generators.backup or {}
        local battery = power.battery or {}
        local control = power.consumers and power.consumers.control or {}
        local emergencyLights = power.consumers and power.consumers.emergency_lighting or {}
        drawRows({
            { getText("UI_BC_Status"), tostring(power.status or "-") },
            { getText("UI_BC_Grid"), power.gridOnline and getText("UI_BC_Online") or getText("UI_BC_Offline") },
            { getText("UI_BC_AvailablePower"), number(power.availableCapacityKw, 1) .. " kW" },
            { getText("UI_BC_AllocatedPower"), number(power.allocatedKw, 1) .. " / " .. number(power.demandKw, 1) .. " kW" },
            { getText("UI_BC_ShedPower"), number(power.shedKw, 1) .. " kW" },
            { getText("UI_BC_Battery"), percent(battery.charge) .. ", "
                .. getText("UI_BC_Output") .. " " .. number(battery.outputKw, 2) .. " kW, "
                .. getText("UI_BC_Charging") .. " " .. number(battery.chargingKw, 2) .. " kW" },
            { getText("UI_BC_EmergencySupply"), getText("UI_BC_ControlBus") .. "=" .. tostring(control.source or "off")
                .. ", " .. getText("UI_BC_EmergencyLights") .. "=" .. tostring(emergencyLights.source or "off") },
            { getText("UI_BC_MainGenerator"), tostring(main.status or "-") .. ", " .. percent(main.fuel) .. ", " .. number(main.loadKw, 1) .. " kW" },
            { getText("UI_BC_BackupGenerator"), tostring(backup.status or "-") .. ", " .. percent(backup.fuel) .. ", " .. number(backup.loadKw, 1) .. " kW" },
        })
    end
    self:drawText(getText("UI_BC_VentilationSection"), x, y, 0.35, 0.75, 1, 1, UIFont.Small)
    y = y + lineHeight
    drawRows({
        { getText("UI_BC_RequestedMode"), tostring(ventilation.requestedMode or "-") },
        { getText("UI_BC_ActiveMode"), tostring(ventilation.activeMode or "-") },
        { getText("UI_BC_Restriction"), tostring(ventilation.reason or "none") },
        { getText("UI_BC_Powered"), ventilation.powerAllocated and getText("UI_BC_Yes") or getText("UI_BC_No") },
        { getText("UI_BC_Operating"), ventilation.operating and getText("UI_BC_Yes") or getText("UI_BC_No") },
        { getText("UI_BC_Status"), tostring(ventilation.status or "-") },
        { getText("UI_BC_Condition"), percent(ventilation.condition) },
        { getText("UI_BC_Filter"), percent(ventilation.filterRemaining) },
        { getText("UI_BC_Airflow"), number(ventilation.airflowM3PerMinute, 0) .. " m3/min" },
        { getText("UI_BC_CO2"), number(ventilation.co2, 0) .. " ppm" },
        { getText("UI_BC_ExternalContamination"), percent(ventilation.externalContamination) },
        { getText("UI_BC_InternalContamination"), percent(ventilation.internalContamination) },
        { getText("UI_BC_Occupants"), tostring(ventilation.telemetry and ventilation.telemetry.totalOccupants or 0) },
        { getText("UI_BC_WorstRoom"), tostring(ventilation.telemetry and ventilation.telemetry.worstRoomId or "-") },
        { getText("UI_BC_Airlock"), tostring(ventilation.airlock and ventilation.airlock.status or "-") },
    })

    local water = snapshot.water
    if water then
        y = y + 5
        self:drawText(getText("UI_BC_WaterSection"), x, y, 0.35, 0.75, 1, 1, UIFont.Small)
        y = y + lineHeight
        local reserve = number(water.stored, 0) .. " / " .. number(water.capacity, 0)
        local storage = water.storage or {}
        local treatment = water.treatment or {}
        drawRows({
            { getText("UI_BC_Adapter"), water.adapterOnline and getText("UI_BC_Online") or getText("UI_BC_Offline") },
            { getText("UI_BC_Requested"), water.pumpRequested and getText("UI_BC_Yes") or getText("UI_BC_No") },
            { getText("UI_BC_Powered"), water.powerAllocated and getText("UI_BC_Yes") or getText("UI_BC_No") },
            { getText("UI_BC_Pump"), water.pumpActive and getText("UI_BC_Enabled") or getText("UI_BC_Disabled") },
            { getText("UI_BC_Status"), tostring(water.status or "-") },
            { getText("UI_BC_Restriction"), tostring(water.reason or "none") },
            { getText("UI_BC_Condition"), percent(water.pumpCondition) },
            { getText("UI_BC_Filter"), percent(water.filterRemaining) },
            { getText("UI_BC_WaterReserve"), reserve .. " L" },
            { getText("UI_BC_CleanWater"), number(storage.cleanLiters, 0) .. " L" },
            { getText("UI_BC_TaintedWater"), number(storage.taintedLiters, 0) .. " L" },
            { getText("UI_BC_WaterContamination"), percent(water.contamination) },
            { getText("UI_BC_WaterFlow"), number(water.flowPerMinute, 2) .. " L/min" },
            { getText("UI_BC_PowerDemand"), number(water.powerDemandKw, 1) .. " kW" },
            { getText("UI_BC_Source"), tostring(water.source or "none") },
            { getText("UI_BC_WaterBypass"), treatment.bypass and getText("UI_BC_Open") or getText("UI_BC_Closed") },
        })
    end

    y = y + 5
    self:drawText(getText("UI_BC_RecentLog") .. ":", x, y, 0.75, 0.80, 0.85, 1, UIFont.Small)
    y = y + lineHeight
    local log = snapshot.auditLog or {}
    local first = math.max(1, #log)
    for index = first, #log do
        local entry = log[index]
        self:drawText("[" .. tostring(entry.category or "system") .. "] " .. tostring(entry.message or ""), x, y, 0.85, 0.85, 0.85, 1, UIFont.Small)
        y = y + lineHeight
    end

    if ClientState.lastError then
        self:drawText(getText("UI_BC_Error") .. ": " .. ClientState.lastError, x, self.height - 148, 1, 0.25, 0.25, 1, UIFont.Small)
    elseif not canControl() then
        self:drawText(getText("UI_BC_BunkerOnly"), x, self.height - 148, 1, 0.75, 0.25, 1, UIFont.Small)
    end
end

function VentilationPanel:close()
    self:removeFromUIManager()
    VentilationPanel.instance = nil
end

function VentilationPanel:new(x, y, playerNum)
    local width = 500
    local height = 1010
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.playerNum = playerNum or 0
    panel.title = getText("UI_BC_SystemsTitle")
    panel:setResizable(false)
    return panel
end

function VentilationPanel.open(playerNum)
    if VentilationPanel.instance then
        VentilationPanel.instance:close()
    end

    local width = 500
    local height = 1010
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    local panel = VentilationPanel:new(x, y, playerNum or 0)
    panel:initialise()
    panel:addToUIManager()
    VentilationPanel.instance = panel
    ClientState.request(getSpecificPlayer(playerNum or 0))
end

local function addContextOption(playerNum, context, worldObjects, test)
    if test and ISWorldObjectContextMenu and ISWorldObjectContextMenu.Test then return true end
    context:addOption(getText("UI_BC_ContextOpen"), playerNum, VentilationPanel.open)
end

Events.OnFillWorldObjectContextMenu.Add(addContextOption)

BunkerCampaign.VentilationPanel = VentilationPanel
return VentilationPanel
