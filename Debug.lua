-- Krazzie - What to do : DEBUG
-- /kwtd debug = hidden labels for the zone you're in. Prints to chat and
-- saves to the SavedVariables file (written on /reload or logout).

local _, ns = ...

function ns.DebugZone()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then ns.Say("Can't tell which zone you're in.") return end

    KrazzieDB = KrazzieDB or {}
    KrazzieDB.debug = {}
    local function Log(line)
        print(line)
        table.insert(KrazzieDB.debug, (line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")))
    end

    Log(("DEBUG: %s (map %d)"):format(ns.ZoneName(mapID), mapID))
    Log("-- Task quests --")
    local quests = C_TaskQuest.GetQuestsOnMap(mapID) or {}
    if #quests == 0 then Log("None found here.") end
    for _, info in ipairs(quests) do
        local questID = info.questID or info.questId
        if questID then
            local parts = { ("[%d] %s"):format(questID, ns.GetTitle(questID)) }
            table.insert(parts, "WQ=" .. tostring(C_QuestLog.IsWorldQuest(questID)))
            local ok, tag = pcall(C_QuestLog.GetQuestTagInfo, questID)
            if ok and tag then
                table.insert(parts, ("tagID=%s tag='%s'"):format(tostring(tag.tagID), tostring(tag.tagName)))
            end
            table.insert(parts, "mapID=" .. tostring(info.mapID))
            Log(table.concat(parts, " | "))
        end
    end

    local function LogPOIs(label, getList)
        Log("-- " .. label .. " --")
        local ok, poiList = pcall(getList, mapID)
        if not ok or not poiList or #poiList == 0 then Log("None found here.") return end
        for _, poiID in ipairs(poiList) do
            local ok2, poi = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
            if ok2 and poi then
                Log(("[poi %d] %s | atlas=%s | widget text=%s")
                    :format(poiID, tostring(poi.name), tostring(poi.atlasName),
                            tostring(ns.GetWidgetText(poi.tooltipWidgetSet, true))))
            end
        end
    end
    if C_AreaPoiInfo then
        if C_AreaPoiInfo.GetAreaPOIForMap then LogPOIs("Area markers", C_AreaPoiInfo.GetAreaPOIForMap) end
        if C_AreaPoiInfo.GetEventsForMap then LogPOIs("Map events", C_AreaPoiInfo.GetEventsForMap) end
    end

    ns.Say("Debug saved. Type /reload to write it to your SavedVariables file.")
end

------------------------------------------------------------
-- /kwtd caps : every known currency and its limits, in chat
------------------------------------------------------------
function ns.DebugCaps()
    local count = 0
    for id, name in pairs(ns.GetKnownCurrencies()) do
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        if ok and info then
            count = count + 1
            local cap = ns.CurrencyCap(id)
            print(("  %s [%d]: have %d | this week %d of %d | max %d%s"):format(
                name, id, info.quantity or 0, info.quantityEarnedThisWeek or 0,
                info.maxWeeklyQuantity or 0, info.maxQuantity or 0,
                cap and (" |cffff6666CAPPED (" .. cap .. ")|r") or ""))
        end
    end
    ns.Say(count .. " currencies checked. A 0 means the game reports no limit of that kind.")
end

------------------------------------------------------------
-- /kwtd att : what does All The Things make visible to other addons?
-- Saves to the SavedVariables file (written on /reload or logout).
------------------------------------------------------------
function ns.DebugATT()
    KrazzieDB = KrazzieDB or {}
    KrazzieDB.debug = {}
    local function Log(line) table.insert(KrazzieDB.debug, line) end

    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("AllTheThings")
    Log("ATT loaded: " .. tostring(loaded))
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        Log("ATT version: " .. tostring(C_AddOns.GetAddOnMetadata("AllTheThings", "Version")))
    end

    -- Any global names that look like they belong to ATT
    local names = {}
    for name, value in pairs(_G) do
        if type(name) == "string" and (name:find("^AllTheThings") or name:find("^ATT")) then
            table.insert(names, ("%s (%s)"):format(name, type(value)))
        end
    end
    table.sort(names)
    Log("-- Global names starting with AllTheThings or ATT: " .. #names .. " --")
    for i, n in ipairs(names) do
        if i > 200 then Log("...and more") break end
        Log(n)
    end

    -- Look inside the likely main tables (top level only)
    local tables = 0
    for _, globalName in ipairs({ "AllTheThings", "ATTC", "ATT" }) do
        local t = _G[globalName]
        if type(t) == "table" then
            tables = tables + 1
            local keys = {}
            for k, v in pairs(t) do table.insert(keys, ("%s (%s)"):format(tostring(k), type(v))) end
            table.sort(keys)
            Log(("-- Inside %s: %d entries --"):format(globalName, #keys))
            for i, k in ipairs(keys) do
                if i > 400 then Log("...and more") break end
                Log(k)
            end
        end
    end

    ns.Say(("ATT check done (loaded: %s, %d main tables found). Type /reload to save it to file.")
        :format(tostring(loaded), tables))
end

------------------------------------------------------------
-- /kwtd att2 : look deeper into ATT. Its database layout, test
-- searches (Brewfest), and the rest of its entries. Saved to file.
------------------------------------------------------------
function ns.DebugATT2()
    KrazzieDB = KrazzieDB or {}
    KrazzieDB.debug = {}
    local function Log(line) table.insert(KrazzieDB.debug, line) end

    local ATT = _G.ATTC or _G.AllTheThings
    if type(ATT) ~= "table" then
        ns.Say("ATT isn't loaded.")
        return
    end

    -- Read a field safely (ATT objects work some values out on the fly)
    local function Get(obj, field)
        local ok, value = pcall(function() return obj[field] end)
        if ok then return value end
    end

    -- One-line description of an ATT object: its useful simple fields
    local FIELDS = { "key", "text", "name", "headerID", "eventID", "npcID", "questID", "itemID",
                     "mountID", "speciesID", "toyID", "achievementID", "decorID", "currencyID",
                     "collectible", "collected", "saved", "e", "u" }
    local function Describe(obj)
        local parts = {}
        for _, f in ipairs(FIELDS) do
            local v = Get(obj, f)
            if v ~= nil and type(v) ~= "table" and type(v) ~= "function" then
                table.insert(parts, f .. "=" .. tostring(v):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
            end
        end
        return table.concat(parts, " ")
    end

    -- 1. Database layout
    local ok, root = pcall(ATT.GetDatabaseRoot)
    if ok and type(root) == "table" then
        Log("-- Database root: " .. Describe(root) .. " --")
        local children = Get(root, "g")
        if type(children) == "table" then
            for i, child in ipairs(children) do
                Log(("[%d] %s"):format(i, Describe(child)))
                local label = tostring(Get(child, "text") or Get(child, "name") or ""):lower()
                if label:find("holiday") or label:find("event") then
                    local sub = Get(child, "g")
                    if type(sub) == "table" then
                        for j, s in ipairs(sub) do
                            if j > 80 then Log("   ...more") break end
                            Log(("   [%d.%d] %s"):format(i, j, Describe(s)))
                        end
                    end
                end
            end
        else
            Log("Root has no 'g' (children) list")
        end
    else
        Log("GetDatabaseRoot failed: " .. tostring(root))
    end

    -- 2. Test searches: Swift Brewfest Ram, Great Brewfest Kodo, Coren Direbrew
    local TESTS = { { "itemID", 33977 }, { "itemID", 37828 }, { "npcID", 23872 } }
    for _, test in ipairs(TESTS) do
        local field, id = test[1], test[2]
        local ok2, results = pcall(ATT.SearchForField, field, id)
        Log(("-- SearchForField(%s, %d): ok=%s type=%s count=%s --"):format(field, id, tostring(ok2),
            type(results), type(results) == "table" and tostring(#results) or "-"))
        if ok2 and type(results) == "table" then
            for i, r in ipairs(results) do
                if i > 3 then break end
                Log("  result: " .. Describe(r))
                local parent, depth = Get(r, "parent"), 0
                while type(parent) == "table" and depth < 8 do
                    Log("    parent: " .. Describe(parent))
                    parent, depth = Get(parent, "parent"), depth + 1
                end
            end
        elseif not ok2 then
            Log("  error: " .. tostring(results))
        end
        local ok3, obj = pcall(ATT.SearchForObject, field, id)
        Log(("  SearchForObject: ok=%s %s"):format(tostring(ok3),
            type(obj) == "table" and Describe(obj) or tostring(obj)))
    end

    -- 3. The rest of ATT's entries (the first check stopped at 400)
    local keys = {}
    for k, v in pairs(ATT) do table.insert(keys, ("%s (%s)"):format(tostring(k), type(v))) end
    table.sort(keys)
    Log("-- ATT entries from 'Sort' onwards --")
    for _, k in ipairs(keys) do
        if k >= "Sort" then Log(k) end
    end

    ns.Say("ATT deep check done. Type /reload to save it to file.")
end
