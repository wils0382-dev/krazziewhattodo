-- Krazzie - What to do : CORE
-- Starts things up and handles slash commands.
-- /kwtd           = open/close the window
-- /kwtd chat      = print the worth-doing list to chat
-- /kwtd chat all  = print everything to chat, skipped quests greyed out
-- /kwtd debug     = hidden labels for the zone you're in (saved to file)
-- /kwtd caps      = every known currency and its weekly/total limits
-- /kwtd att       = what All The Things exposes to other addons (saved to file)
-- /kwtd att2      = ATT's database layout and test searches (saved to file)
-- /kwtd event X   = what you're missing from event X, e.g. /kwtd event brewfest (needs ATT)

local _, ns = ...

local function PrintToChat(result, showAll)
    for _, w in ipairs(result.weeklies or {}) do
        print("  |cffffd100This week:|r " .. ns.FormatWeekly(w))
    end
    for _, event in ipairs(result.events or {}) do
        for _, text in ipairs(ns.Events:Lines(event, result.settings)) do
            print("  |cffffd100" .. event.name .. ":|r " .. text)
        end
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
-- These are registered "safely": if the game renames one, nothing breaks
for _, event in ipairs({
    "WORLD_QUEST_COMPLETED_BY_SPELL",   -- world quest finished without a hand-in
    "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED",
    "TRANSMOG_COLLECTION_SOURCE_ADDED", "ACHIEVEMENT_EARNED",
    "CALENDAR_UPDATE_EVENT_LIST",       -- the calendar has loaded today's holidays
}) do
    pcall(watcher.RegisterEvent, watcher, event)
end
watcher:SetScript("OnEvent", function(_, event)
    -- Anything except map-marker changes might change what events you're missing
    if event ~= "AREA_POIS_UPDATED" then ns.Events:Invalidate() end
    RefreshSoon()
end)

-- Light redraws: when bags or currencies change, only redraw (so token
-- counts on event lines stay current) - no rescan, so it's cheap.
local redrawPending = false
local function RedrawSoon()
    if redrawPending then return end
    redrawPending = true
    C_Timer.After(1, function()
        redrawPending = false
        ns.Window:Redraw()
    end)
end
local light = CreateFrame("Frame")
pcall(light.RegisterEvent, light, "BAG_UPDATE_DELAYED")
pcall(light.RegisterEvent, light, "CURRENCY_DISPLAY_UPDATE")
light:SetScript("OnEvent", RedrawSoon)

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
        if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end -- load holidays
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
    elseif msg == "att2" then
        ns.DebugATT2()
    elseif msg:find("^event") then
        ns.Events:Missing(msg:match("^event%s+(.+)$"))
    elseif msg:find("chat") then
        local showAll = msg:find("all") ~= nil
        ns.Scan(function(result) PrintToChat(result, showAll) end)
    else
        ns.Window:Toggle()
    end
end
