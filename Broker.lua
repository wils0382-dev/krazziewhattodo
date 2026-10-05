-- Krazzie - What to do : BROKER (Titan Panel + minimap icon)
-- Uses the shared LibDataBroker and LibDBIcon libraries. Krazzie doesn't
-- bundle them: it borrows the copies other addons (Routine, Titan Panel)
-- already load. If none are loaded, this file quietly does nothing.

local _, ns = ...
local Broker = {}
ns.Broker = Broker

local ICON = "Interface\\Icons\\INV_Misc_Map_01"
local dataObject, lastSummary

function Broker:Init()
    if not LibStub then return end
    local ldb = LibStub("LibDataBroker-1.1", true) -- true = "don't error if missing"
    if not ldb then return end

    -- The "data object": Titan Panel and other display addons show this
    dataObject = ldb:NewDataObject("Krazzie", {
        type  = "data source",
        label = "Krazzie",
        text  = "...",
        icon  = ICON,
        OnClick = function(_, button)
            if button == "RightButton" then
                ns.Window:OpenSettings()
            else
                ns.Window:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cffff9900Krazzie|r - What to do")
            if lastSummary then tooltip:AddLine(lastSummary, 1, 1, 1, true) end
            -- Your characters, most to do first
            local alts = ns.GetAltSummaries()
            if #alts > 0 then
                tooltip:AddLine(" ")
                for i, entry in ipairs(alts) do
                    if i > 10 then break end
                    tooltip:AddLine(ns.AltLine(entry), 1, 1, 1)
                end
            end
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffaaaaaaLeft-click:|r open or close")
            tooltip:AddLine("|cffaaaaaaRight-click:|r settings")
        end,
    })

    -- Minimap button (remembers where you drag it around the minimap)
    local icon = LibStub("LibDBIcon-1.0", true)
    if icon then
        local db = ns.GetDB()
        db.minimap = db.minimap or {}
        icon:Register("Krazzie", dataObject, db.minimap)
        self.icon = icon
        self:ApplySettings()
    end
end

function Broker:ApplySettings()
    if not self.icon then return end
    local show = ns.GetSettings().showMinimap
    ns.GetDB().minimap.hide = not show
    if show then self.icon:Show("Krazzie") else self.icon:Hide("Krazzie") end
end

-- Called after every scan: shows e.g. "Krazzie: 5 to do" in Titan Panel
function Broker:Update(result)
    lastSummary = ns.SummaryText(result)
    if dataObject then
        local text = result.worth .. " to do"
        if (result.handIn or 0) > 0 then text = text .. ", " .. result.handIn .. " to hand in" end
        dataObject.text = text
    end
end
