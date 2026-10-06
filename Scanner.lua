-- Krazzie - What to do : SCANNER
-- Finds world quests and Special Assignments, applies your rules,
-- and builds a sorted list. Doesn't draw anything - Window.lua and
-- Core.lua decide how to show the results.

local _, ns = ...

------------------------------------------------------------
-- 1. SMALL HELPERS
------------------------------------------------------------
local function GetRanks(settings)
    local ranks = {}
    for i, category in ipairs(settings.priority) do ranks[category] = i end
    return ranks
end

local function GetGold(questID)
    if GetQuestLogRewardMoney then
        local ok, copper = pcall(GetQuestLogRewardMoney, questID)
        if ok and type(copper) == "number" then return copper end
    end
    return 0
end

-- First equippable item reward, as a small table (or nil)
local function GetGear(questID)
    if not GetNumQuestLogRewards then return nil end
    local ok, count = pcall(GetNumQuestLogRewards, questID)
    if not ok or not count then return nil end
    for i = 1, count do
        local ok2, name, _, _, _, isUsable, itemID, itemLevel = pcall(GetQuestLogRewardInfo, i, questID)
        if ok2 and itemID then
            local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
            if equipLoc and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
                return { name = name, itemLevel = itemLevel, equipLoc = equipLoc, isUsable = isUsable }
            end
        end
    end
    return nil
end

-- Currency rewards: list of { id, name, amount }
local function GetCurrencies(questID)
    local found = {}
    if C_QuestLog.GetQuestRewardCurrencies then
        local ok, list = pcall(C_QuestLog.GetQuestRewardCurrencies, questID)
        if ok and list then
            for _, c in ipairs(list) do
                if c.currencyID then
                    table.insert(found, { id = c.currencyID, name = c.name,
                        amount = c.totalRewardAmount or c.baseRewardAmount or 0 })
                end
            end
            return found
        end
    end
    -- Older way of asking, in case the newer one isn't available
    if GetNumQuestLogRewardCurrencies then
        local ok, count = pcall(GetNumQuestLogRewardCurrencies, questID)
        for i = 1, (ok and count or 0) do
            local ok2, name, _, amount, currencyID = pcall(GetQuestLogRewardCurrencyInfo, i, questID)
            if ok2 and currencyID then
                table.insert(found, { id = currencyID, name = name, amount = amount or 0 })
            end
        end
    end
    return found
end

function ns.GetTitle(questID)
    local title = C_TaskQuest.GetQuestInfoByQuestID and C_TaskQuest.GetQuestInfoByQuestID(questID)
    return title or ("Quest " .. questID)
end

function ns.ZoneName(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.name or ("Map " .. mapID)
end

-- Two-handed weapons fill both hands. Next to one, neither an off-hand nor a single
-- one-hander is a real upgrade (swapping would leave a hand empty).
local TWO_HANDED = { INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }
local NOT_FOR_TWO_HANDERS = {
    INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, -- off-hands
    INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true,                         -- one-handers
}

local function UsingTwoHanderOnly()
    local mainHand = GetInventoryItemLink("player", 16)
    if not mainHand or GetInventoryItemLink("player", 17) then return false end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(mainHand)
    return TWO_HANDED[equipLoc] == true
end

-- Item level of what you're wearing in the given slot(s). Empty slot = 0.
local function GetEquippedLevel(slots)
    local lowest
    for _, slot in ipairs(slots) do
        local link = GetInventoryItemLink("player", slot)
        local level = (link and C_Item.GetDetailedItemLevelInfo(link)) or 0
        if not lowest or level < lowest then lowest = level end
    end
    return lowest or 0
end

------------------------------------------------------------
-- 2. TOOLTIP READING (map markers)
-- Tooltips are built from "widgets"; there are several kinds.
------------------------------------------------------------
local WIDGET_READERS = {
    "GetTextWithStateWidgetVisualizationInfo",
    "GetIconAndTextWidgetVisualizationInfo",
    "GetStatusBarWidgetVisualizationInfo",
    "GetTextColumnRowVisualizationInfo",
}

local function ReadWidget(widgetID)
    for _, fn in ipairs(WIDGET_READERS) do
        local reader = C_UIWidgetManager[fn]
        if reader then
            local ok, info = pcall(reader, widgetID)
            if ok and info then
                if info.barMax and info.barMax > 0 then
                    return ("%d/%d"):format(info.barValue or 0, info.barMax), fn
                end
                local text = info.text or info.overrideBarText or info.leftText
                if text and text ~= "" then return text, fn end
            end
        end
    end
    return nil
end

-- All readable text from a marker's tooltip. details=true adds debug info.
function ns.GetWidgetText(widgetSetID, details)
    if not (widgetSetID and C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID) then return nil end
    local ok, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, widgetSetID)
    if not ok or not widgets then return nil end
    local texts = {}
    for _, w in ipairs(widgets) do
        local text, fn = ReadWidget(w.widgetID)
        if details then
            table.insert(texts, ("{id=%s type=%s via=%s text=%s}")
                :format(tostring(w.widgetID), tostring(w.widgetType), tostring(fn), tostring(text)))
        elseif text then
            table.insert(texts, text)
        end
    end
    if #texts == 0 then return nil end
    return table.concat(texts, " / ")
end

------------------------------------------------------------
-- 3. LOCKED SPECIAL ASSIGNMENTS (map markers with "Capstone" icons)
------------------------------------------------------------
local function CollectSpecialAssignments()
    local found, seen = {}, {}
    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap) then return found end
    for _, zoneID in ipairs(ns.ZONES) do
        local ok, pois = pcall(C_AreaPoiInfo.GetAreaPOIForMap, zoneID)
        for _, poiID in ipairs((ok and pois) or {}) do
            if not seen[poiID] then
                local ok2, poi = pcall(C_AreaPoiInfo.GetAreaPOIInfo, zoneID, poiID)
                if ok2 and poi and poi.atlasName and poi.atlasName:find("Capstone") then
                    seen[poiID] = true
                    -- Tooltip reads e.g. "Complete 1 world quest in Eversong to unlock"
                    local text = ns.GetWidgetText(poi.tooltipWidgetSet)
                    table.insert(found, {
                        zoneID    = zoneID,
                        name      = poi.name or "Special Assignment",
                        locked    = poi.atlasName:find("Locked") ~= nil,
                        remaining = text and tonumber(text:match("(%d+)")),
                    })
                end
            end
        end
    end
    return found
end

------------------------------------------------------------
-- 4. RULES: which categories does a quest fit?
------------------------------------------------------------
local function Evaluate(questID, zoneHasLockedSA, settings)
    local reasons = {}

    -- Special Assignment (unlocked = world quest with tag 286)
    local isSA = false
    local okTag, tag = pcall(C_QuestLog.GetQuestTagInfo, questID)
    if okTag and tag and tag.tagID == ns.SA_TAG_ID then
        isSA = true
        table.insert(reasons, { category = "sa", text = "|cffa335eeSA: Ready|r" })
    end

    -- Gear
    local gear = GetGear(questID)
    if gear and gear.isUsable and gear.itemLevel then
        local slots = ns.SLOTS[gear.equipLoc]
        -- Wielding a two-hander with an empty off-hand? Off-hands and one-handers aren't upgrades.
        if NOT_FOR_TWO_HANDERS[gear.equipLoc] and UsingTwoHanderOnly() then slots = nil end
        if slots then
            local current = GetEquippedLevel(slots)
            local gain = gear.itemLevel - current
            -- Empty slot and you've said not to count those? Then it's not an upgrade.
            local skipEmpty = (current == 0) and not settings.emptySlotUpgrades
            if gain >= settings.minUpgrade and not skipEmpty then
                local text
                if current == 0 then
                    -- Nothing equipped there: the biggest upgrade there is
                    text = ("|cff00ff00Upgrade (empty slot)|r %s (ilvl %d)"):format(gear.name or "item", gear.itemLevel)
                else
                    text = ("|cff00ff00Upgrade +%d|r %s (%d vs your %d)")
                        :format(gain, gear.name or "item", gear.itemLevel, current)
                end
                table.insert(reasons, { category = "gear", text = text, gain = gain })
            end
        end
    end

    -- Any gear (for disenchanting) - only if it isn't already an upgrade
    local isUpgrade = false
    for _, r in ipairs(reasons) do if r.category == "gear" then isUpgrade = true end end
    if gear and not isUpgrade then
        table.insert(reasons, { category = "anygear",
            text = ("|cffccccccGear|r %s (ilvl %s)"):format(gear.name or "item", gear.itemLevel or "?") })
    end

    -- Currencies: each real currency is its own category, learned as we see it.
    -- Reputation "currencies" all share one category instead.
    local currencies = GetCurrencies(questID)
    for _, c in ipairs(currencies) do
        if ns.IsRepCurrency(c.id) then
            c.isRep = true
            table.insert(reasons, { category = "rep",
                text = ("|cff00ff96+%d %s rep|r"):format(c.amount, c.name or "faction") })
        else
            ns.LearnCurrency(c.id, c.name)
            c.capped = ns.CurrencyCap(c.id)
            -- Capped currencies don't count (unless you've switched that off)
            if not (c.capped and settings.respectCaps) then
                table.insert(reasons, { category = "cur:" .. c.id,
                    text = ("|cff40c0ff%d %s|r%s"):format(c.amount, c.name or "currency",
                        c.capped and " |cffff6666(capped)|r" or "") })
            end
        end
    end

    -- Gold
    local copper = GetGold(questID)
    if copper >= settings.minGold * 10000 then -- 1 gold = 10,000 copper
        table.insert(reasons, { category = "gold", text = "|cffffd100Gold|r " .. GetCoinTextureString(copper) })
    end

    -- Unlock
    if zoneHasLockedSA then
        table.insert(reasons, { category = "unlock", text = "|cff0070ddUnlocks SA|r" })
    end

    -- Plain reward summary for greyed-out lines
    local summary = {}
    if copper > 0 then table.insert(summary, GetCoinTextureString(copper)) end
    if gear then table.insert(summary, ("%s (ilvl %s)"):format(gear.name or "item", gear.itemLevel or "?")) end
    for _, c in ipairs(currencies) do
        table.insert(summary, (c.isRep and "+%d %s rep" or "%d %s"):format(c.amount, c.name or "currency")
            .. (c.capped and " (capped)" or ""))
    end
    if #summary == 0 then table.insert(summary, "other reward") end

    return reasons, table.concat(summary, ", "), copper, isSA
end

------------------------------------------------------------
-- 5. COLLECT world quests
------------------------------------------------------------
local function CollectWorldQuests()
    local found, seen = {}, {}
    for _, zoneID in ipairs(ns.ZONES) do
        for _, info in ipairs(C_TaskQuest.GetQuestsOnMap(zoneID) or {}) do
            local questID = info.questID or info.questId
            -- Skip quests you've already done (the map can lag a few seconds behind)
            local done = C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID)
            if questID and not seen[questID] and not done and C_QuestLog.IsWorldQuest(questID) then
                seen[questID] = true
                table.insert(found, { questID = questID, zoneID = info.mapID or zoneID })
            end
        end
    end
    return found
end

local function RequestRewards(list)
    local missing = 0
    for _, q in ipairs(list) do
        if HaveQuestRewardData and not HaveQuestRewardData(q.questID) then
            C_TaskQuest.RequestPreloadRewardData(q.questID)
            missing = missing + 1
        end
    end
    return missing
end

------------------------------------------------------------
-- 5b. WEEKLY QUESTS already in your quest log
------------------------------------------------------------
local function CollectWeeklies()
    local found = {}
    if not (C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return found end
    local WEEKLY = (Enum and Enum.QuestFrequency and Enum.QuestFrequency.Weekly) or 2
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and info.questID and not info.isHeader and not info.isHidden
           and info.frequency == WEEKLY then
            local ready = C_QuestLog.ReadyForTurnIn and C_QuestLog.ReadyForTurnIn(info.questID)
            -- Progress text, e.g. "World Quests completed: 7/10"
            local texts = {}
            for _, o in ipairs(C_QuestLog.GetQuestObjectives(info.questID) or {}) do
                if o.text and o.text ~= "" then table.insert(texts, o.text) end
            end
            table.insert(found, { questID = info.questID, title = info.title or ns.GetTitle(info.questID),
                                  ready = ready == true, progress = table.concat(texts, ", ") })
        end
    end
    table.sort(found, function(a, b)
        if a.ready ~= b.ready then return a.ready end -- ready to hand in first
        return a.title < b.title
    end)
    return found
end

------------------------------------------------------------
-- 6. BUILD the sorted list (grouped by zone, best first)
------------------------------------------------------------
local function BuildEntries(list)
    local settings = ns.GetSettings() -- account or character, see Profile.lua
    local ranks = GetRanks(settings)
    local zoneOrder = {}
    for i, id in ipairs(ns.ZONES) do zoneOrder[id] = i end

    local specials = CollectSpecialAssignments()
    local lockedZones, lockedCount = {}, 0
    for _, sa in ipairs(specials) do
        if sa.locked then
            lockedZones[ns.COUNTS_AS[sa.zoneID] or sa.zoneID] = true
            lockedCount = lockedCount + 1
        end
    end

    local entries = {}
    for _, q in ipairs(list) do
        local reasons, summary, copper, isSA = Evaluate(q.questID, lockedZones[ns.COUNTS_AS[q.zoneID] or q.zoneID], settings)

        -- Your own tick/cross for this quest on this character
        local choice = ns.GetChoice(q.questID)
        if choice == "yes" then
            table.insert(reasons, { category = "pick", text = "|cff66ccffYour pick|r" })
        end

        -- Drop reasons for categories you've switched off
        local kept = {}
        for _, r in ipairs(reasons) do
            if not ns.IsCategoryOff(settings, r.category) then table.insert(kept, r) end
        end
        reasons = kept

        local best
        for _, r in ipairs(reasons) do
            local rank = ranks[r.category] or 99
            if not best or rank < best then best = rank end
        end
        table.sort(reasons, function(a, b) return (ranks[a.category] or 99) < (ranks[b.category] or 99) end)
        if choice == "no" then best = nil end -- hidden: not worth doing, sinks to the bottom

        -- Size of the gear upgrade (if any), so bigger upgrades sort first
        local gain = 0
        for _, r in ipairs(reasons) do
            if r.gain and r.gain > gain then gain = r.gain end
        end
        table.insert(entries, { zoneID = q.zoneID, questID = q.questID, title = ns.GetTitle(q.questID),
                                rank = best, reasons = reasons, summary = summary, gold = copper,
                                isQuest = true, isSA = isSA, choice = choice, hidden = choice == "no",
                                gain = gain })
    end

    local saOff = ns.IsCategoryOff(settings, "sa")
    for _, sa in ipairs(saOff and {} or specials) do
        local status = sa.locked
            and ("Locked" .. (sa.remaining and (" - %d more WQ to unlock"):format(sa.remaining) or ""))
            or "Ready"
        table.insert(entries, { zoneID = sa.zoneID, title = sa.name, rank = ranks.sa or 99, gold = 0,
                                reasons = { { category = "sa", text = "|cffa335eeSA: " .. status .. "|r" } } })
    end

    table.sort(entries, function(a, b)
        local za, zb = zoneOrder[a.zoneID] or 99, zoneOrder[b.zoneID] or 99
        if za ~= zb then return za < zb end
        local ra, rb = a.rank or 999, b.rank or 999
        if ra ~= rb then return ra < rb end
        if (a.gain or 0) ~= (b.gain or 0) then return (a.gain or 0) > (b.gain or 0) end -- bigger upgrade first
        if a.gold ~= b.gold then return a.gold > b.gold end
        return a.title < b.title
    end)

    local worth, ready = 0, 0
    for _, e in ipairs(entries) do
        if e.rank and e.isQuest then worth = worth + 1 end
        if e.isSA and not e.hidden then ready = ready + 1 end
    end

    local weeklies = settings.showWeeklies and CollectWeeklies() or {}
    local handIn = 0
    for _, w in ipairs(weeklies) do if w.ready then handIn = handIn + 1 end end

    local events = ns.Events and ns.Events:GetActive(settings) or {}

    return { entries = entries, total = #list, worth = worth, ready = ready, locked = lockedCount,
             weeklies = weeklies, handIn = handIn, events = events, settings = settings }
end

------------------------------------------------------------
-- 7. PUBLIC: scan, then hand the result to whoever asked
------------------------------------------------------------
-- If reward data is still loading (common just after a loading screen),
-- wait and check again: up to 4 checks, 2 seconds apart.
local MAX_CHECKS, CHECK_DELAY = 4, 2

function ns.Scan(onDone)
    local checks = 0
    local function attempt()
        checks = checks + 1
        local list = CollectWorldQuests() -- re-collect each time, the map may still be loading
        local stillLoading = (#list == 0) or (RequestRewards(list) > 0)
        if stillLoading and checks < MAX_CHECKS then
            C_Timer.After(CHECK_DELAY, attempt)
            return
        end
        local result = BuildEntries(list)
        if ns.SaveSnapshot then ns.SaveSnapshot(result) end -- for the Alts list
        if ns.Broker then ns.Broker:Update(result) end      -- keep the panel icon's count fresh
        onDone(result)
    end
    attempt()
end

-- One weekly quest as a line of text
function ns.FormatWeekly(w)
    local status = w.ready and "|cff00ff00Ready to hand in!|r"
        or ("|cffaaaaaa" .. (w.progress ~= "" and w.progress or "In progress") .. "|r")
    return w.title .. " - " .. status
end

-- One quest as a line of text (used by both chat and the window)
function ns.FormatLine(e)
    if e.rank then
        local texts = {}
        for _, r in ipairs(e.reasons) do table.insert(texts, r.text) end
        return e.title .. " - " .. table.concat(texts, " + ")
    end
    return ("|cff888888%s - %s%s|r"):format(e.title, e.summary or "", e.hidden and " (hidden)" or "")
end

function ns.SummaryText(r)
    if r.total == 0 and #r.entries == 0 then
        return "No world quests found. Open your world map, then Refresh."
    end
    local text = ("%d of %d world quests worth doing. Special Assignments: %d ready, %d locked")
        :format(r.worth, r.total, r.ready, r.locked)
    if (r.handIn or 0) > 0 then text = text .. (". |cff00ff00%d weekly to hand in|r"):format(r.handIn) end
    return text
end
