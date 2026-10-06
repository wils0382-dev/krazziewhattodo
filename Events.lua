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

-- Turn a small table into text, e.g. { {"c", 1, 100} } -> {{c,1,100}} (for the debug file)
local function Serialize(value, depth)
    depth = depth or 0
    if type(value) ~= "table" then return tostring(value) end
    if depth > 3 then return "{...}" end
    local parts = {}
    for k, v in pairs(value) do
        local text = Serialize(v, depth + 1)
        if type(k) ~= "number" then text = tostring(k) .. "=" .. text end
        table.insert(parts, text)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

------------------------------------------------------------
-- Costs. ATT writes a price as { {"i", itemID, amount} } or { {"c", currencyID, amount} }
------------------------------------------------------------
-- ATT prices come in a few shapes. Turn them all into a list of { kind, id, amount }:
--   { {"i", itemID, n} }  item cost        { {"c", currencyID, n} }  currency cost
--   a plain number, or { {"g", copper} }   gold cost (in copper)
local function CostParts(cost)
    if type(cost) == "number" then return { { "g", 0, cost } } end
    if type(cost) ~= "table" then return {} end
    local parts = {}
    for _, part in ipairs(cost) do
        if type(part) == "table" then
            if part[1] == "g" then
                table.insert(parts, { "g", 0, part[3] or part[2] or 0 })
            else
                table.insert(parts, { part[1], part[2], part[3] or 1 })
            end
        end
    end
    return parts
end

local function HeldAmount(kind, id)
    if kind == "g" then
        return GetMoney() -- in copper
    elseif kind == "i" then
        -- bags, bank, reagent bank and warband bank
        local ok, count = pcall(C_Item.GetItemCount, id, true, false, true, true)
        return (ok and count) or 0
    elseif kind == "c" then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        return (ok and info and info.quantity) or 0
    end
    return 0
end

local function CostName(kind, id)
    if kind == "g" then
        return "gold"
    elseif kind == "i" then
        local name = C_Item.GetItemNameByID(id)
        if not name then C_Item.RequestLoadItemDataByID(id) end
        return name or ("item " .. id)
    elseif kind == "c" then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        return (ok and info and info.name) or ("currency " .. id)
    end
    return tostring(kind) .. " " .. tostring(id)
end

local function CanAfford(parts)
    for _, part in ipairs(parts) do
        if HeldAmount(part[1], part[2]) < part[3] then return false end
    end
    return true
end

-- 4925 -> "4,925"
local function Comma(n)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end

-- Amount as text: gold shown in whole gold ("1,250g"), everything else as a number
local function AmountText(kind, amount)
    if kind == "g" then return Comma(math.floor(amount / 10000)) .. "g" end
    return Comma(amount)
end

-- Done by this character - or, for account-wide quests only, by any character
local function IsQuestDone(questID)
    if C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) then return true end
    local accountWide = C_QuestLog.IsAccountQuest and C_QuestLog.IsAccountQuest(questID)
    if accountWide and C_QuestLog.IsQuestFlaggedCompletedOnAccount
       and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID) then
        return true
    end
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
                                        source = path, quest = childQuest, cost = Get(child, "cost") })
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
            a = { label = label, items = {}, quests = {} }
            byLabel[label] = a
            table.insert(list, a)
        end
        table.insert(a.items, m)
        if m.quest then a.quests[m.quest] = true end
    end
    return list
end

-- A calendar time as one comparable number, e.g. 202610071030
local function Stamp(t)
    return (((t.year * 100 + t.month) * 100 + t.monthDay) * 100 + (t.hour or 0)) * 100 + (t.minute or 0)
end

-- A holiday's description (it often names the expansion, e.g. for Timewalking)
local function HolidayDescription(day, index)
    if not C_Calendar.GetHolidayInfo then return "" end
    local ok, a, b = pcall(C_Calendar.GetHolidayInfo, 0, day, index)
    if not ok then return "" end
    if type(a) == "table" then return a.description or "" end
    return b or "" -- older style: name, description, ...
end

-- Holidays running RIGHT NOW (started, and not yet ended), from the in-game calendar
local function ActiveHolidays()
    local list = {}
    if not (C_Calendar and C_Calendar.GetNumDayEvents and C_DateAndTime) then return list end
    if CalendarFrame and CalendarFrame:IsShown() then return nil end -- don't move your calendar view
    local now = C_DateAndTime.GetCurrentCalendarTime()
    local nowStamp = Stamp(now)
    pcall(C_Calendar.SetAbsMonth, now.month, now.year)
    local ok, count = pcall(C_Calendar.GetNumDayEvents, 0, now.monthDay)
    for i = 1, (ok and count or 0) do
        local ok2, ev = pcall(C_Calendar.GetDayEvent, 0, now.monthDay, i)
        if ok2 and ev and ev.calendarType == "HOLIDAY" and ev.title then
            local started = not ev.startTime or Stamp(ev.startTime) <= nowStamp
            local notEnded = not ev.endTime or Stamp(ev.endTime) > nowStamp
            if started and notEnded then
                table.insert(list, { title = ev.title, description = HolidayDescription(now.monthDay, i) })
            end
        end
    end
    return list
end

-- Expansion names, for events split by expansion (Timewalking)
local EXPANSIONS = { "burning crusade", "wrath of the lich king", "cataclysm", "mists of pandaria",
                     "warlords of draenor", "legion", "battle for azeroth", "shadowlands",
                     "dragonflight", "the war within" }
local function ExpansionIn(text)
    text = (text or ""):lower()
    for _, e in ipairs(EXPANSIONS) do
        if text:find(e, 1, true) then return e end
    end
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
        local event = FindEvent(att, holiday.title)
        if event then
            local missing = CollectMissing(event)
            if #missing > 0 then
                table.insert(events, {
                    name = holiday.title,
                    -- Which expansion is running (Timewalking): title first, then description
                    running = ExpansionIn(holiday.title) or ExpansionIn(holiday.description),
                    activities = GroupByActivity(missing, holiday.title),
                })
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

    -- Count the types you care about, and add up prices for the ones with a cost
    -- Each item is judged on its own quest: done today = its quest is complete
    local counts, doneCounts, available, doneToday = {}, {}, 0, 0
    local totals, totalOrder = {}, {}
    local priced, affordable = 0, 0
    for _, m in ipairs(activity.items) do
        local itemDone = m.quest and IsQuestDone(m.quest)
        if not off[m.type] and itemDone then
            doneToday = doneToday + 1
            doneCounts[m.type] = (doneCounts[m.type] or 0) + 1
        elseif not off[m.type] then
            available = available + 1
            counts[m.type] = (counts[m.type] or 0) + 1
            local costParts = CostParts(m.cost)
            if #costParts > 0 then
                priced = priced + 1
                if CanAfford(costParts) then affordable = affordable + 1 end
                for _, part in ipairs(costParts) do
                    local key = tostring(part[1]) .. ":" .. tostring(part[2])
                    if not totals[key] then
                        totals[key] = { kind = part[1], id = part[2], amount = 0 }
                        table.insert(totalOrder, key)
                    end
                    totals[key].amount = totals[key].amount + part[3]
                end
            end
        end
    end

    if available == 0 and doneToday == 0 then return nil end -- nothing you want here

    -- Everything done today: describe what was done, greyed
    local done = (available == 0)
    local shown = done and doneCounts or counts

    local parts, bestRank = {}, nil
    for _, t in ipairs(TYPE_ORDER) do
        local n = shown[t]
        if n and n > 0 then
            table.insert(parts, n .. " " .. t)
            bestRank = bestRank or TYPE_RANK[t]
        end
    end

    -- e.g. " · 3 affordable now (320/4,925 Brewfest Prize Token)"
    local costText = ""
    if priced > 0 then
        local held = {}
        for _, key in ipairs(totalOrder) do
            local t = totals[key]
            table.insert(held, ("%s/%s %s"):format(AmountText(t.kind, HeldAmount(t.kind, t.id)),
                AmountText(t.kind, t.amount), CostName(t.kind, t.id)))
        end
        costText = (" %s|cff%s%d affordable now|r |cffaaaaaa(%s)|r"):format("\194\183 ",
            affordable > 0 and "00ff00" or "aaaaaa", affordable, table.concat(held, ", "))
    end

    local text = activity.label .. " - " .. table.concat(parts, ", ") .. costText
    if done then
        text = "|cff888888" .. text .. " (done today)|r"
    elseif doneToday > 0 then
        text = text .. (" |cff888888(+%d done today)|r"):format(doneToday)
    end
    return text, bestRank, done
end

-- Lines for one event, sorted: not done first, then best type, then name.
-- Events split by expansion (Timewalking) show only the running expansion,
-- plus one total line across every expansion.
function Events:Lines(event, settings)
    local shown, splitByExpansion = {}, false
    for _, a in ipairs(event.activities) do
        local expansion = ExpansionIn(a.label)
        if expansion then splitByExpansion = true end
        -- Hide other expansions' lines, but only if we know which one is running
        if not (event.running and expansion and expansion ~= event.running) then
            table.insert(shown, a)
        end
    end

    local rows = {}
    for _, a in ipairs(shown) do
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

    -- Total across every expansion (only when we've hidden some)
    if splitByExpansion and event.running and #shown < #event.activities then
        local total = { label = "All expansions (total)", items = {}, quests = {} }
        for _, a in ipairs(event.activities) do
            if ExpansionIn(a.label) then
                for _, m in ipairs(a.items) do table.insert(total.items, m) end
            end
        end
        local text = self:Describe(total, settings)
        if text then table.insert(lines, "|cffaaaaaa" .. text .. "|r") end
    end
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
    -- What the calendar says is running now (to check expansion detection)
    for _, h in ipairs(ActiveHolidays() or {}) do
        table.insert(KrazzieDB.debug, ("Running now: %s | desc: %s | expansion: %s")
            :format(h.title, h.description, tostring(ExpansionIn(h.title) or ExpansionIn(h.description))))
    end
    for _, m in ipairs(missing) do
        table.insert(KrazzieDB.debug, ("%s | %s | %s | quest=%s | cost=%s")
            :format(m.type, m.name, m.source, tostring(m.quest), Serialize(m.cost)))
    end
end
