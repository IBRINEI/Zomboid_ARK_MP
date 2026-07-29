require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local Util = BunkerCampaign.Util
local VentilationSimulation = {}

local function calculateStatus(ventilation)
    if ventilation.condition <= 0.05 then return "failed" end
    if ventilation.co2 >= 2500 or ventilation.internalContamination >= 0.60 then return "emergency" end
    if ventilation.condition < 0.75 or ventilation.filterRemaining < 0.25 or ventilation.co2 > 1200 or ventilation.internalContamination > 0.10 then
        return "degraded"
    end
    return "operational"
end

function VentilationSimulation.update(ventilation, deltaMinutes)
    deltaMinutes = Util.numberOr(deltaMinutes, 1, 0, 60)

    local rules = Constants.VENTILATION
    local oldStatus = ventilation.status
    local oldFilter = ventilation.filterRemaining
    local condition = Util.clamp(ventilation.condition, 0, 1)
    local external = Util.clamp(ventilation.externalContamination, 0, 1)

    local operating = ventilation.enabled and ventilation.powerAllocated == true and condition > 0.05
    ventilation.operating = operating

    if operating then
        ventilation.co2 = ventilation.co2 - rules.CO2_REMOVAL_PER_MINUTE * condition * deltaMinutes

        if ventilation.filterRemaining > 0 then
            local conditionPenalty = 1 / math.max(condition, 0.25)
            local contaminationFactor = 1 + external * rules.FILTER_CONTAMINATION_MULTIPLIER
            local filterUse = rules.BASE_FILTER_USE_PER_MINUTE * contaminationFactor * conditionPenalty * deltaMinutes
            ventilation.filterRemaining = math.max(0, ventilation.filterRemaining - filterUse)
        end

        if ventilation.filterRemaining > 0 then
            ventilation.internalContamination = math.max(0, ventilation.internalContamination - rules.CONTAMINATION_CLEAR_PER_MINUTE * condition * deltaMinutes)
        elseif external > 0 then
            ventilation.internalContamination = math.min(1, ventilation.internalContamination + rules.CONTAMINATION_INGRESS_PER_MINUTE * external * condition * deltaMinutes)
        end
    else
        ventilation.co2 = ventilation.co2 + rules.CO2_RISE_PER_MINUTE * deltaMinutes
    end

    ventilation.co2 = Util.clamp(ventilation.co2, rules.MIN_CO2, rules.MAX_CO2)
    ventilation.filterRemaining = Util.clamp(ventilation.filterRemaining, 0, 1)
    ventilation.internalContamination = Util.clamp(ventilation.internalContamination, 0, 1)
    ventilation.status = calculateStatus(ventilation)

    return {
        statusChanged = oldStatus ~= ventilation.status,
        previousStatus = oldStatus,
        filterExhausted = oldFilter > 0 and ventilation.filterRemaining <= 0,
    }
end

BunkerCampaign.VentilationSimulation = VentilationSimulation
return VentilationSimulation
