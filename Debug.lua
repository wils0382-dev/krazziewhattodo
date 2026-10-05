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
