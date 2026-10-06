-- Krazzie - What to do : EVENTS (uses All The Things, if loaded)
-- /kwtd event <name>  e.g. /kwtd event brewfest
-- Lists what you're still missing from an event, grouped by type, with
-- where each thing comes from. Reads ATT's data; never copies it.

local _, ns = ...
local Events = {}
ns.Events = Events

-- ATT's sections we search for events (from the /kwtd att2 detective)
local EVENT_SECTIONS = { [-36] = true,  -- Holidays
                         [-734] = true } -- World Event

-- The kinds of collectible thing we care about, by ATT's key name
local TYPES = {
    mountID       = "Mount",
    speciesID     = "Pet",
    toyID         = "Toy",
    achievementID = "Achievement",
    decorID       = "Decor",
    sourceID      = "Appearance",
    itemID        = "Item",
    titleID       = "Title",
    illusionID    = "Illusion",
}

local function GetATT()
    local att = _G.ATTC or _G.AllTheThings
    if type(att) == "table" then return att end
end

-- Read a field safely (ATT works some values out on the fly)
local function Get(obj, field)
    local ok, value = pcall(function() return obj[field] end)
    if ok then return value end
end

local function Clean(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Best available name for an ATT object
local function NameOf(obj)
    local name = Get(obj, "text") or Get(obj, "name")
    if type(name) == "string" and name ~= "" and name ~= "Retrieving data" then return Clean(name) end
    local itemID = Get(obj, "itemID")
    if itemID and C_Item.GetItemNameByID then
        local n = C_Item.GetItemNameByID(itemID)
        if n then return n end
        C_Item.RequestLoadItemDataByID(itemID) -- ask the game, so it's ready next time
    end
    local spellID = Get(obj, "mountID") -- ATT's mountID is the mount's spell
    if spellID and C_Spell and C_Spell.GetSpellName then
        local n = C_Spell.GetSpellName(spellID)
        if n then return n end
    end
    local key = Get(obj, "key")
    return ("%s %s"):format(tostring(key), tostring(key and Get(obj, key)))
end

-- Find an event by name inside ATT's Holidays / World Event sections
local function FindEvent(att, wanted)
    local ok, root = pcall(att.GetDatabaseRoot)
    if not ok or type(root) ~= "table" then return nil end
    wanted = wanted:lower()
    for _, section in ipairs(Get(root, "g") or {}) do
        if EVENT_SECTIONS[Get(section, "headerID")] then
            for _, event in ipairs(Get(section, "g") or {}) do
                local name = tostring(Get(event, "text") or ""):lower()
                if name == wanted or name:find(wanted, 1, true) then return event end
            end
        end
    end
end

-- Walk down through an event, collecting things you haven't got.
-- "path" remembers where we are, e.g. "Coren Direbrew > Coren Special Loot Attempt"
local function Walk(node, path, out, depth, counter)
    if depth > 20 or counter.n > 20000 then return end -- safety limits
    for _, child in ipairs(Get(node, "g") or {}) do
        counter.n = counter.n + 1
        if Get(child, "u") == nil then -- skip anything ATT marks as unobtainable
            local key = Get(child, "key")
            if TYPES[key] and Get(child, "collectible") == true and not Get(child, "collected") then
                table.insert(out, { type = TYPES[key], name = NameOf(child), source = path })
            end
            local label = Get(child, "text")
            local childPath = path
            if type(label) == "string" and label ~= "" and label ~= "Retrieving data" then
                childPath = (path == "") and Clean(label) or (path .. " > " .. Clean(label))
            end
            Walk(child, childPath, out, depth + 1, counter)
        end
    end
end

-- Holidays running today, according to the in-game calendar (for later)
local function LogTodaysHolidays(Log)
    if not (C_Calendar and C_Calendar.GetNumDayEvents and C_DateAndTime) then
        Log("Calendar: not available")
        return
    end
    local now = C_DateAndTime.GetCurrentCalendarTime()
    pcall(C_Calendar.OpenCalendar)
    pcall(C_Calendar.SetAbsMonth, now.month, now.year)
    local ok, count = pcall(C_Calendar.GetNumDayEvents, 0, now.monthDay)
    Log(("-- Calendar today: %s events --"):format(tostring(ok and count or "error")))
    for i = 1, (ok and count or 0) do
        local ok2, ev = pcall(C_Calendar.GetDayEvent, 0, now.monthDay, i)
        if ok2 and ev then
            Log(("%s | type=%s | eventID=%s"):format(tostring(ev.title),
                tostring(ev.calendarType), tostring(ev.eventID)))
        end
    end
end

function Events:Missing(eventName)
    local att = GetATT()
    if not att then ns.Say("This needs All The Things to be loaded.") return end
    if not eventName or eventName == "" then ns.Say("Which event? e.g. /kwtd event brewfest") return end

    local event = FindEvent(att, eventName)
    if not event then ns.Say("Couldn't find an event called '" .. eventName .. "' in ATT.") return end

    local missing, counter = {}, { n = 0 }
    Walk(event, "", missing, 0, counter)
    table.sort(missing, function(a, b)
        if a.type ~= b.type then return a.type < b.type end
        return a.name < b.name
    end)

    -- Count by type
    local counts, order = {}, {}
    for _, m in ipairs(missing) do
        if not counts[m.type] then counts[m.type] = 0; table.insert(order, m.type) end
        counts[m.type] = counts[m.type] + 1
    end
    local summary = {}
    for _, t in ipairs(order) do table.insert(summary, counts[t] .. " " .. t) end

    -- Chat: summary and the first 20
    local title = NameOf(event)
    ns.Say(("%s: %d things missing%s"):format(title, #missing,
        #summary > 0 and (" (" .. table.concat(summary, ", ") .. ")") or ""))
    for i, m in ipairs(missing) do
        if i > 20 then print("  ...full list saved for /reload") break end
        print(("  |cffffd100%s|r %s |cff888888- %s|r"):format(m.type, m.name, m.source ~= "" and m.source or title))
    end

    -- File: everything, plus today's calendar
    KrazzieDB = KrazzieDB or {}
    KrazzieDB.debug = {}
    local function Log(line) table.insert(KrazzieDB.debug, line) end
    Log(("%s: %d missing, %d entries checked"):format(title, #missing, counter.n))
    for _, m in ipairs(missing) do
        Log(("%s | %s | %s"):format(m.type, m.name, m.source))
    end
    LogTodaysHolidays(Log)
end
