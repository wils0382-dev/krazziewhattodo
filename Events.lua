-- Krazzie - What to do : EVENTS (uses All The Things, if loaded)
-- While a holiday is running, finds what you're still missing from it
-- and groups it by activity (a boss, the vendors, quests...).
-- Reads ATT's data while the game runs; never copies it.
-- /kwtd event <name> also lists every missing item in chat and the save file.

local _, ns = ...
local Events = {}
ns.Events = Events

-- ATT's sections that hold events (found with the /kwtd att2 detective)
local EVENT_SECTIONS = { [-36] = true,   -- Holidays
                         [-734] = true } -- World Event

-- ATT's key name -> our type name
local TYPES = {
    mountID = "Mount", speciesID = "Pet", toyID = "Toy", decorID = "Decor",
    sourceID = "Appearance", achievementID = "Achievement", titleID = "Title",
    illusionID = "Illusion", itemID = "Item",
}
-- Display and sorting order (most exciting first)
local TYPE_ORDER = { "Mount", "Pet", "Toy", "Decor", "Appearance", "Achievement", "Title", "Illusion", "Item" }
ns.EVENT_TYPES = TYPE_ORDER
local TYPE_RANK = {}
for i, t in ipairs(TYPE_ORDER) do TYPE_RANK[t] = i end

local CACHE_SECONDS = 300
local cache = { time = 0, events = nil }

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function GetATT()
    local att = _G.ATTC or _G.AllTheThings
    if type(att) == "table" then return att end
end

-- Read a field safely (ATT works some values out on the fly)
local function Get(obj, field)
    local ok, value = pcall(function() return obj[field] end)
    if ok then return value end
end

-- Strip colours and links: "|cnIQ3:|Hitem:...|h[Barrel Helm]|h" -> "Barrel Helm"
local function CleanName(text)
    text = text:gsub("|H.-|h%[(.-)%]|h", "%1")
    text = text:gsub("|cn.-:", "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

local function NameOf(obj, key, id)
    local name = Get(obj, "text") or Get(obj, "name")
    if type(name) == "string" and name ~= "" and name ~= "Retrieving data" then return CleanName(name) end
    if key == "sourceID" and C_TransmogCollection and C_TransmogCollection.GetSourceInfo then
        local ok, info = pcall(C_TransmogCollection.GetSourceInfo, id)
        if ok and info and info.name then return info.name end
    end
    local itemID = Get(obj, "itemID") or (key == "toyID" and id)
    if itemID and C_Item.GetItemNameByID then
        local n = C_Item.GetItemNameByID(itemID)
        if n then return n end
        C_Item.RequestLoadItemDataByID(itemID) -- ready for next time
    end
    if key == "mountID" and C_Spell and C_Spell.GetSpellName then
        local n = C_Spell.GetSpellName(id) -- ATT's mountID is the mount's spell
        if n then return n end
    end
    return ("%s #%s"):format(TYPES[key] or tostring(key), tostring(id))
end

local function IsQuestDone(questID)
    if C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) then return true end
    if C_QuestLog.IsQuestFlaggedCompletedOnAccount and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID) then return true end
    return false
end

------------------------------------------------------------
-- Finding events and what's missing
------------------------------------------------------------
-- Find an event by name. Exact names win over partial matches.
local function FindEvent(att, wanted)
    local ok, root = pcall(att.GetDatabaseRoot)
    if not ok or type(root) ~= "table" then return nil end
    wanted = wanted:lower()
    local partial
    for _, section in ipairs(Get(root, "g") or {}) do
        if EVENT_SECTIONS[Get(section, "headerID")] then
            for _, event in ipairs(Get(section, "g") or {}) do
                local name = tostring(Get(event, "text") or ""):lower()
                if name == wanted then return event end
                if not partial and name:find(wanted, 1, true) then partial = event end
            end
        end
    end
    return partial
end

-- Walk down an event, collecting things you haven't got.
-- path = where we are (e.g. "Coren Direbrew > Coren Special Loot Attempt")
-- questID = the nearest quest above us, so we can tell if it's done today
local function Walk(node, path, out, seen, depth, counter, questID)
    if depth > 20 or counter.n > 20000 then return end -- safety limits
    for _, child in ipairs(Get(node, "g") or {}) do
        counter.n = counter.n + 1
        if Get(child, "u") == nil then -- skip anything ATT marks as unobtainable
            local key = Get(child, "key")
            local childQuest = (key == "questID" and Get(child, "questID")) or questID
            if TYPES[key] and Get(child, "collectible") == true and not Get(child, "collected") then
                local id = Get(child, key)
                local dedupe = key .. ":" .. tostring(id)
                if not seen[dedupe] then -- ATT lists some things twice (Alliance + Horde)
                    seen[dedupe] = true
                    table.insert(out, { type = TYPES[key], name = NameOf(child, key, id),
                                        source = path, quest = childQuest })
                end
            end
            local label = Get(child, "text")
            local childPath = path
            if type(label) == "string" and label ~= "" and label ~= "Retrieving data" then
                childPath = (path == "") and CleanName(label) or (path .. " > " .. CleanName(label))
            end
            Walk(child, childPath, out, seen, depth + 1, counter, childQuest)
        end
    end
end

local function CollectMissing(event)
    local missing, counter = {}, { n = 0 }
    Walk(event, "", missing, {}, 0, counter, nil)
    return missing, counter.n
end

-- Group missing items by activity: the first step of their path
local function GroupByActivity(missing, eventName)
    local byLabel, list = {}, {}
    for _, m in ipairs(missing) do
        local label = m.source:match("^([^>]+)") or eventName
        label = label:gsub("%s+$", "")
        local a = byLabel[label]
        if not a then
            a = { label = label, counts = {}, quests = {} }
            byLabel[label] = a
            table.insert(list, a)
        end
        a.counts[m.type] = (a.counts[m.type] or 0) + 1
        if m.quest then a.quests[m.quest] = true end
    end
    return list
end

-- Holidays running today, from the in-game calendar
local function ActiveHolidays()
    local names = {}
    if not (C_Calendar and C_Calendar.GetNumDayEvents and C_DateAndTime) then return names end
    if CalendarFrame and CalendarFrame:IsShown() then return nil end -- don't move your calendar view
    local now = C_DateAndTime.GetCurrentCalendarTime()
    pcall(C_Calendar.SetAbsMonth, now.month, now.year)
    local ok, count = pcall(C_Calendar.GetNumDayEvents, 0, now.monthDay)
    for i = 1, (ok and count or 0) do
        local ok2, ev = pcall(C_Calendar.GetDayEvent, 0, now.monthDay, i)
        if ok2 and ev and ev.calendarType == "HOLIDAY" and ev.title then
            table.insert(names, ev.title)
        end
    end
    return names
end

------------------------------------------------------------
-- Public
------------------------------------------------------------
function Events:Invalidate()
    cache.time = 0
end

-- Running events and their activities (cached for 5 minutes)
function Events:GetActive(settings)
    if not settings.showEvents then return {} end
    local att = GetATT()
    if not att then return {} end
    if cache.events and (time() - cache.time) < CACHE_SECONDS then return cache.events end

    local holidays = ActiveHolidays()
    if not holidays then return cache.events or {} end -- calendar open: keep what we had

    local events = {}
    for _, holiday in ipairs(holidays) do
        local event = FindEvent(att, holiday)
        if event then
            local missing = CollectMissing(event)
            if #missing > 0 then
                table.insert(events, { name = holiday, activities = GroupByActivity(missing, holiday) })
            end
        end
    end
    cache.events, cache.time = events, time()
    return events
end

-- One activity as a line of text, using your type switches.
-- Returns text, best type rank (for sorting), done today?  or nil if nothing you want.
function Events:Describe(activity, settings)
    local off = settings.eventTypesOff or {}
    local parts, bestRank = {}, nil
    for _, t in ipairs(TYPE_ORDER) do
        local n = activity.counts[t]
        if n and n > 0 and not off[t] then
            table.insert(parts, n .. " " .. t)
            bestRank = bestRank or TYPE_RANK[t]
        end
    end
    if #parts == 0 then return nil end

    -- Done today = it has quests above it, and they're all complete
    local hasQuest, allDone = false, true
    for questID in pairs(activity.quests) do
        hasQuest = true
        if not IsQuestDone(questID) then allDone = false end
    end
    local done = hasQuest and allDone

    local text = activity.label .. " - " .. table.concat(parts, ", ")
    if done then text = "|cff888888" .. text .. " (done today)|r" end
    return text, bestRank, done
end

-- Lines for one event, sorted: not done first, then best type, then name
function Events:Lines(event, settings)
    local rows = {}
    for _, a in ipairs(event.activities) do
        local text, rank, done = self:Describe(a, settings)
        if text then table.insert(rows, { text = text, rank = rank, done = done, label = a.label }) end
    end
    table.sort(rows, function(x, y)
        if x.done ~= y.done then return not x.done end
        if x.rank ~= y.rank then return x.rank < y.rank end
        return x.label < y.label
    end)
    local lines = {}
    for _, r in ipairs(rows) do table.insert(lines, r.text) end
    return lines
end

------------------------------------------------------------
-- /kwtd event <name> : every missing item, in chat and the save file
------------------------------------------------------------
function Events:Missing(eventName)
    local att = GetATT()
    if not att then ns.Say("This needs All The Things to be loaded.") return end
    if not eventName or eventName == "" then ns.Say("Which event? e.g. /kwtd event brewfest") return end
    local event = FindEvent(att, eventName)
    if not event then ns.Say("Couldn't find an event called '" .. eventName .. "' in ATT.") return end

    local missing, checked = CollectMissing(event)
    table.sort(missing, function(a, b)
        if a.type ~= b.type then return (TYPE_RANK[a.type] or 99) < (TYPE_RANK[b.type] or 99) end
        return a.name < b.name
    end)

    local title = CleanName(tostring(Get(event, "text") or eventName))
    ns.Say(("%s: %d things missing"):format(title, #missing))
    for i, m in ipairs(missing) do
        if i > 20 then print("  ...full list saved for /reload") break end
        print(("  |cffffd100%s|r %s |cff888888- %s|r"):format(m.type, m.name, m.source))
    end

    KrazzieDB = KrazzieDB or {}
    KrazzieDB.debug = { ("%s: %d missing, %d entries checked"):format(title, #missing, checked) }
    for _, m in ipairs(missing) do
        table.insert(KrazzieDB.debug, ("%s | %s | %s | quest=%s"):format(m.type, m.name, m.source, tostring(m.quest)))
    end
end
