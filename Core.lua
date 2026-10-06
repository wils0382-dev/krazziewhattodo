-- Krazzie - What to do : CORE
-- Starts things up and handles slash commands.
-- /kwtd           = open/close the window
-- /kwtd chat      = print the worth-doing list to chat
-- /kwtd chat all  = print everything to chat, skipped quests greyed out
-- /kwtd debug     = hidden labels for the zone you're in (saved to file)
-- /kwtd caps      = every known currency and its weekly/total limits
-- /kwtd att       = what All The Things exposes to other addons (saved to file)

local _, ns = ...

local function PrintToChat(result, showAll)
    for _, w in ipairs(result.weeklies or {}) do
        print("  |cffffd100This week:|r " .. ns.FormatWeekly(w))
    end
    local lastZone
    for _, e in ipairs(result.entries) do
        if e.rank or showAll then
            if e.zoneID ~= lastZone then
                lastZone = e.zoneID
                print("  |cffffd100" .. ns.ZoneName(e.zoneID) .. "|r")
            end
            print("    " .. ns.FormatLine(e))
        end
    end
    ns.Say(ns.SummaryText(result))
end

------------------------------------------------------------
-- AUTO-REFRESH: when you hand in a quest, or map markers change
-- (e.g. a Special Assignment unlocks), refresh the open window.
------------------------------------------------------------
local refreshPending = false

-- Waits a moment so the game's data can catch up. Extra events in that
-- time are ignored, so a burst of updates = one refresh.
local function RefreshSoon(delay)
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(delay or 2, function()
        refreshPending = false
        if ns.Window:IsShown() then
            ns.Window:Refresh(true)
        else
            ns.Scan(function() end) -- window closed: just update the panel icon's count
        end
    end)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("QUEST_TURNED_IN")   -- you handed in a quest
watcher:RegisterEvent("AREA_POIS_UPDATED") -- map markers changed (SA unlocked, etc.)
watcher:RegisterEvent("QUEST_ACCEPTED")    -- picked up a quest (e.g. a new weekly)
-- Some world quests complete without a hand-in; register this one safely
pcall(watcher.RegisterEvent, watcher, "WORLD_QUEST_COMPLETED_BY_SPELL")
watcher:SetScript("OnEvent", function() RefreshSoon() end)

------------------------------------------------------------
-- LOGIN, /reload and loading screens
------------------------------------------------------------
local brokerReady = false
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, _, isInitialLogin, isReloadingUi)
    if not (isInitialLogin or isReloadingUi) then
        RefreshSoon(3) -- came through a loading screen: refresh once things settle
        return
    end
    if not brokerReady then
        ns.Broker:Init()
        brokerReady = true
    end
    C_Timer.After(5, function()
        local settings = ns.GetSettings()
        if settings.openOnLogin then
            ns.Window:Open()
        else
            ns.Scan(function() end) -- still scan, so the panel icon has a count
        end
        if settings.chatOnLogin then
            ns.Scan(function(result) PrintToChat(result, false) end)
        end
    end)
end)

SLASH_KRAZZIEWTD1 = "/kwtd"
SlashCmdList.KRAZZIEWTD = function(msg)
    msg = (msg or ""):lower()
    if msg:find("debug") then
        ns.DebugZone()
    elseif msg == "caps" then
        ns.DebugCaps()
    elseif msg == "att" then
        ns.DebugATT()
    elseif msg:find("chat") then
        local showAll = msg:find("all") ~= nil
        ns.Scan(function(result) PrintToChat(result, showAll) end)
    else
        ns.Window:Toggle()
    end
end
