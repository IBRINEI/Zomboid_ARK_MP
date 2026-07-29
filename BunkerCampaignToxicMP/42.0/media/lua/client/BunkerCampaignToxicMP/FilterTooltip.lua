require "ISUI/ISToolTipInv"
require "BunkerCampaignToxicMP/Constants"

BunkerCampaignToxicMP = BunkerCampaignToxicMP or {}

if not BunkerCampaignToxicMP.filterTooltipInstalled then
    BunkerCampaignToxicMP.filterTooltipInstalled = true
    local originalRender = ISToolTipInv.render

    function ISToolTipInv:render()
        local item = self.item
        if not item then
            return originalRender(self)
        end

        local fullType = item:getFullType()
        local isFilter = fullType == "Base.GasMaskFilter"
        local isMask = BunkerCampaignToxicMP.Constants.PROTECTIVE_MASKS[item:getType()] == true
        local percent = tonumber(item:getModData().percent)
        local contamination = tonumber(item:getModData()[BunkerCampaignToxicMP.Constants.CONTAMINATION_MODDATA_KEY])
        local labels = {}
        if (isFilter or isMask) and percent then
            percent = math.max(0, math.min(1, percent))
            labels[#labels + 1] = string.format("Filter charge: %.1f%%", percent * 100)
        end
        if contamination and contamination > BunkerCampaignToxicMP.Constants.SURFACE_TRACE then
            contamination = math.max(0, math.min(100, contamination))
            labels[#labels + 1] = string.format("Surface contamination: %.1f%%", contamination)
        end
        if #labels == 0 then
            return originalRender(self)
        end

        local label = table.concat(labels, "\n")
        local previousTooltip = item:getTooltip()
        local core = getCore()
        local showModInfo = core:getOptionShowItemModInfo()

        local ok, message = pcall(function()
            -- InventoryItem.DoTooltip appends its dynamic Tooltip line to the
            -- normal layout.  Hide the much less important mod attribution for
            -- this render so the changing charge stays inside the visible
            -- characteristics block instead of below it.
            item:setTooltip(label)
            if showModInfo then core:setOptionShowItemModInfo(false) end
            originalRender(self)
        end)

        item:setTooltip(previousTooltip)
        if showModInfo then core:setOptionShowItemModInfo(true) end
        if not ok then
            print("[BunkerCampaignToxicMP] filter tooltip failed: " .. tostring(message))
            originalRender(self)
        end
    end
end
