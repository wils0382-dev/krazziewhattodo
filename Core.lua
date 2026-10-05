-- Krazzie - What to do : CORE
-- Starts things up and handles slash commands.
-- /kwtd           = open/close the window
-- /kwtd chat      = print the worth-doing list to chat
-- /kwtd chat all  = print everything to chat, skipped quests greyed out
-- /kwtd debug     = hidden labels for the zone you're in (saved to file)

local _, ns = ...

local function PrintToChat(result, showAll)
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

-- On login or /reload: wait 5 seconds for the game to settle, then go
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, _, isInitialLogin, isReloadingUi)
    if isInitialLogin or isReloadingUi then
        C_Timer.After(5, function()
            local settings = ns.GetSettings()
            if settings.openOnLogin then ns.Window:Open() end
            if settings.chatOnLogin then
                ns.Scan(function(result) PrintToChat(result, false) end)
            end
        end)
    end
end)

SLASH_KRAZZIEWTD1 = "/kwtd"
SlashCmdList.KRAZZIEWTD = function(msg)
    msg = (msg or ""):lower()
    if msg:find("debug") then
        ns.DebugZone()
    elseif msg:find("chat") then
        local showAll = msg:find("all") ~= nil
        ns.Scan(function(result) PrintToChat(result, showAll) end)
    else
        ns.Window:Toggle()
    end
end
