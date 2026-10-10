-- Krazzie - What to do : ACTIVITIES
-- This week's activities, read from the map in every Midnight zone:
--   * Bountiful Delves (map icon "delves-bountiful")
--   * Events (Saltheril's Soiree, Abundance, Stormarion Assault, Prey...)
--   * Ritual Sites
-- Found with the /kwtd activities detective. Icon names are the same in
-- every game language, so they're what we match on.

local _, ns = ...
local Activities = {}
ns.Activities = Activities

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
-- Strip colours, icons and grammar codes from tooltip text
local function Clean(text)
    text = tostring(text or "")
    text = text:gsub("|T.-|t", "")                 -- icons
    text = text:gsub("|4(.-):(.-);", "%2")        -- "|4Hr:Hr;" plural codes
    text = text:gsub("|cn.-:", "")                 -- named colours
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")     -- hex colours
    text = text:gsub("|r", ""):gsub("|n", " ")
    text = text:gsub("[\r\n]+", " "):gsub("%s+", " ")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Done this week? True if any quest linked to this marker (Settings.lua) is complete
local function IsDone(poiID)
    for _, questID in ipairs(ns.ACTIVITY_QUESTS[poiID] or {}) do
        if C_QuestLog.IsQuestFlaggedCompleted(questID) then return true end
    end
    return false
end

-- Seconds until the weekly reset (for "skip this week" choices)
local function SecondsToReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local ok, s = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
        if ok and s then return s end
    end
    return 7 * 24 * 60 * 60
end

------------------------------------------------------------
-- Choices: tick/cross on an activity, per character, until weekly reset
------------------------------------------------------------
local function GetChoices()
    local char = ns.GetCharDB()
    char.activityChoices = char.activityChoices or {}
    return char.activityChoices
end

function Activities:GetChoice(key)
    local choices = GetChoices()
    local c = choices[key]
    if c and c.expires < time() then choices[key] = nil return nil end
    return c and c.choice
end

function Activities:SetChoice(key, choice)
    local choices = GetChoices()
    if choices[key] and choices[key].choice == choice then
        choices[key] = nil -- clicking the same button again clears it
        return
    end
    choices[key] = { choice = choice, expires = time() + SecondsToReset() }
end

------------------------------------------------------------
-- What counts as an activity
------------------------------------------------------------
-- Returns a label for a map marker, or nil if it isn't an activity we track
local function KindOf(atlas, fromList)
    atlas = (atlas or ""):lower()
    if fromList == "delves" then
        return atlas:find("bountiful", 1, true) and "Bountiful Delve" or nil -- regular delves: skip
    end
    if fromList == "events" then
        if atlas:find("majorattacks", 1, true) then return "Region" end -- e.g. Void Incursion progress
        return "Event"
    end
    if atlas:find("ritual", 1, true) then return "Ritual Site" end
    return nil -- portals, flight points, vendors...
end

local KIND_ORDER = { ["Bountiful Delve"] = 1, ["Event"] = 2, ["Ritual Site"] = 3, ["Region"] = 4 }

-- Short extra detail for a line (story variant for delves, a reward hint for events)
local function DetailOf(kind, widgetText)
    local text = Clean(widgetText)
    if kind == "Bountiful Delve" then
        local story = text:match("Story Variant:%s*(.-)%s*$") or text:match("Story Variant:%s*([^/]+)")
        return story and story:gsub("%s*/.*$", "")
    end
    if kind == "Region" then
        local done, total = text:match("(%d+)/(%d+)")
        if done and tonumber(total) > 0 then
            return math.floor(tonumber(done) / tonumber(total) * 100) .. "% progress"
        end
    end
    return nil
end

-- Restored Coffer Keys you hold, read from a bountiful delve's tooltip
local function KeysFrom(widgetText)
    local text = Clean(widgetText)
    return tonumber(text:match("Restored Coffer Key:%s*(%d+)"))
end

------------------------------------------------------------
-- Collect everything on the map this week
------------------------------------------------------------
function Activities:Collect(settings)
    local result = { list = {}, keys = nil }
    if not settings.showActivities or not C_AreaPoiInfo then return result end

    local seen = {}
    local SOURCES = {
        { name = "delves", get = C_AreaPoiInfo.GetDelvesForMap },
        { name = "events", get = C_AreaPoiInfo.GetEventsForMap },
        { name = "markers", get = C_AreaPoiInfo.GetAreaPOIForMap },
    }
    for _, zoneID in ipairs(ns.ZONES) do
        for _, source in ipairs(SOURCES) do
            if source.get then
                local ok, poiList = pcall(source.get, zoneID)
                for _, poiID in ipairs((ok and poiList) or {}) do
                    if not seen[poiID] then -- the same event shows on several maps
                        local ok2, poi = pcall(C_AreaPoiInfo.GetAreaPOIInfo, zoneID, poiID)
                        local kind = ok2 and poi and KindOf(poi.atlasName, source.name)
                        if kind then
                            seen[poiID] = true
                            local widgetText = ns.GetWidgetText(poi.tooltipWidgetSet) or ""
                            if kind == "Bountiful Delve" then
                                result.keys = result.keys or KeysFrom(widgetText)
                            end
                            local key = "act:" .. poiID
                            table.insert(result.list, {
                                key = key, kind = kind, zoneID = zoneID,
                                name = Clean(poi.name),
                                detail = DetailOf(kind, widgetText),
                                choice = self:GetChoice(key),
                                done = IsDone(poiID),
                            })
                        end
                    end
                end
            end
        end
    end

    -- Picks first, then open ones, then done, then skipped; then by kind and name
    local function Place(x)
        if x.choice == "no" then return 3 end
        if x.done then return 2 end
        if x.choice == "yes" then return 0 end
        return 1
    end
    table.sort(result.list, function(a, b)
        local pa, pb = Place(a), Place(b)
        if pa ~= pb then return pa < pb end
        local ka, kb = KIND_ORDER[a.kind] or 9, KIND_ORDER[b.kind] or 9
        if ka ~= kb then return ka < kb end
        return a.name < b.name
    end)
    return result
end

-- One activity as a line of text
function Activities:Format(a)
    local extra = ns.ZoneName(a.zoneID)
    if a.detail then extra = extra .. " \194\183 " .. a.detail end
    local text = ("|cffb0b0ff[%s]|r %s |cff888888(%s)|r"):format(a.kind, a.name, extra)
    if a.choice == "yes" then text = text .. " |cff66ccffYour pick|r" end
    if a.choice == "no" then
        text = "|cff888888" .. Clean(text) .. " (skipped this week)|r"
    elseif a.done then
        text = "|cff888888" .. Clean(text) .. " (done this week)|r"
    end
    return text
end
