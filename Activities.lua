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

-- Done this week? True if any quest linked to this activity (Settings.lua) is
-- complete. Links can use the activity's name or its map marker ID.
local function IsDone(name, poiID)
    local wanted = (name or ""):lower()
    for link, questIDs in pairs(ns.ACTIVITY_QUESTS) do
        local matches = (link == poiID) or (type(link) == "string" and link:lower() == wanted)
        if matches then
            for _, questID in ipairs(questIDs) do
                if C_QuestLog.IsQuestFlaggedCompleted(questID) then return true end
            end
        end
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
-- Delve progress this week, from the Great Vault's World row
------------------------------------------------------------
local function WorldVaultType()
    local t = Enum and Enum.WeeklyRewardChestThresholdType
    return (t and t.World) or 6
end

-- Tiers of every delve/world activity done this week, highest first (or nil)
local function RunTiers()
    if not (C_WeeklyRewards and C_WeeklyRewards.GetSortedProgressForActivity) then return nil end
    local ok, list = pcall(C_WeeklyRewards.GetSortedProgressForActivity, WorldVaultType(), false)
    if not ok or type(list) ~= "table" then return nil end
    local tiers = {}
    for _, entry in ipairs(list) do
        local tier = entry.difficulty or entry.level or 0
        for _ = 1, (entry.numPoints or 1) do table.insert(tiers, tier) end
    end
    table.sort(tiers, function(a, b) return a > b end)
    return tiers
end

-- The vault's World row: total progress, the last threshold, and each slot's tier
local function VaultWorld()
    if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities) then return nil end
    local ok, list = pcall(C_WeeklyRewards.GetActivities, WorldVaultType())
    if not ok or type(list) ~= "table" or #list == 0 then return nil end
    table.sort(list, function(a, b) return (a.threshold or 0) < (b.threshold or 0) end)
    local info = { progress = 0, threshold = 0, slots = {} }
    for _, a in ipairs(list) do
        info.progress = math.max(info.progress, a.progress or 0)
        info.threshold = math.max(info.threshold, a.threshold or 0)
        table.insert(info.slots, { threshold = a.threshold or 0, level = a.level or 0,
                                   reached = (a.progress or 0) >= (a.threshold or 1) })
    end
    return info
end

-- How many of this week's runs were at the goal tier or higher.
-- Exact if the game lists every run; otherwise estimated from the vault slots.
function Activities:DelveProgress(settings)
    local tier, goal = settings.delveTier or 11, settings.delveGoal or 4
    local vault = VaultWorld()
    local tiers = RunTiers()
    local count, exact = 0, false
    if tiers then
        exact = true
        for _, t in ipairs(tiers) do if t >= tier then count = count + 1 end end
    elseif vault then
        -- Slot N's tier is your Nth best run: if it's high enough, you've done at least N
        for _, slot in ipairs(vault.slots) do
            if slot.reached and slot.level >= tier then count = math.max(count, slot.threshold) end
        end
    end
    return { count = count, goal = goal, tier = tier, exact = exact, vault = vault }
end

------------------------------------------------------------
-- Collect everything on the map this week
------------------------------------------------------------
function Activities:Collect(settings)
    local result = { list = {}, keys = nil }
    if not settings.showActivities then return result end
    result.delves = self:DelveProgress(settings)
    if not C_AreaPoiInfo then return result end

    local seen, seenName = {}, {}
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
                        -- On your "never show" list (Settings.lua)? Skip it.
                        if kind then
                            for hiddenName in pairs(ns.HIDDEN_ACTIVITIES or {}) do
                                if hiddenName:lower() == Clean(poi.name):lower() then kind = nil end
                            end
                        end
                        -- Same name and type under a different marker number? Same activity.
                        local nameKey = kind and (kind .. ":" .. Clean(poi.name):lower())
                        if kind and seenName[nameKey] then
                            seen[poiID] = true
                            kind = nil
                        end
                        local widgetText = ""
                        if kind then
                            seen[poiID] = true
                            seenName[nameKey] = true
                            widgetText = ns.GetWidgetText(poi.tooltipWidgetSet) or ""
                            if kind == "Bountiful Delve" then
                                result.keys = result.keys or KeysFrom(widgetText)
                                -- Listed one by one only if you've asked for that; the progress line is always there
                                if not settings.showBountifulDelves then kind = nil end
                            end
                        end
                        if kind then
                            local key = "act:" .. poiID
                            table.insert(result.list, {
                                key = key, kind = kind, zoneID = zoneID,
                                name = Clean(poi.name),
                                detail = DetailOf(kind, widgetText),
                                choice = self:GetChoice(key),
                                done = IsDone(Clean(poi.name), poiID),
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

-- The delve progress line, e.g.
-- "Delves at tier 11+: 2/4 · Great Vault (world): 5/8 · Restored Coffer Keys: 11"
function Activities:DelveLine(delves, keys)
    if not delves then return nil end
    local dot = " \194\183 "
    local done = delves.count >= delves.goal
    local parts = { ("Delves at tier %d+: %s%d/%d"):format(delves.tier,
        delves.exact and "" or "~", math.min(delves.count, delves.goal), delves.goal) }
    if delves.vault then
        table.insert(parts, ("Great Vault (world): %d/%d"):format(
            math.min(delves.vault.progress, delves.vault.threshold), delves.vault.threshold))
    end
    if keys then table.insert(parts, "Restored Coffer Keys: " .. keys) end
    local text = table.concat(parts, dot)
    if done then return "|cff888888" .. text .. " (done this week)|r", true end
    return text, false
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
