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
