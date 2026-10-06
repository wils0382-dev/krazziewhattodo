-- Krazzie - What to do : PROFILE
-- Works out which settings apply right now:
--   1. the DEFAULTS in Settings.lua
--   2. overridden by your account-wide choices
--   3. overridden by this character's own choices (if switched on)

local _, ns = ...

local function CopyTable(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = type(v) == "table" and CopyTable(v) or v
    end
    return copy
end

function ns.CharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

-- The whole save file, with its main sections created if missing
function ns.GetDB()
    KrazzieDB = KrazzieDB or {}
    KrazzieDB.account = KrazzieDB.account or {}
    KrazzieDB.account.settings = KrazzieDB.account.settings or {}
    KrazzieDB.chars = KrazzieDB.chars or {}
    return KrazzieDB
end

-- This character's section of the save file
function ns.GetCharDB()
    local db = ns.GetDB()
    local key = ns.CharKey()
    db.chars[key] = db.chars[key] or {}
    return db.chars[key]
end

function ns.UsesOwnSettings()
    return ns.GetCharDB().useOwn == true
end

-- Switch this character's own settings on (starting as a copy of the account's) or off
function ns.SetUseOwn(on)
    local char = ns.GetCharDB()
    if on then
        char.useOwn = true
        char.settings = char.settings or CopyTable(ns.GetDB().account.settings)
    else
        char.useOwn = nil
    end
end

-- The settings table being edited right now (account, or this character)
local function GetActiveStore()
    local char = ns.GetCharDB()
    if char.useOwn then
        char.settings = char.settings or {}
        return char.settings
    end
    return ns.GetDB().account.settings
end

function ns.SetSetting(key, value)
    GetActiveStore()[key] = type(value) == "table" and CopyTable(value) or value
end

-- Clear whichever settings are being edited, back to the defaults
function ns.ResetActive()
    local store = GetActiveStore()
    for k in pairs(store) do store[k] = nil end
end

------------------------------------------------------------
-- Currencies Krazzie has seen in quest rewards (shared by all characters)
------------------------------------------------------------
-- Some "currencies" are really reputation with a faction. The game can tell us.
function ns.IsRepCurrency(currencyID)
    if C_CurrencyInfo and C_CurrencyInfo.GetFactionGrantedByCurrency then
        local ok, factionID = pcall(C_CurrencyInfo.GetFactionGrantedByCurrency, currencyID)
        if ok and factionID and factionID > 0 then return true end
    end
    return false
end

function ns.GetKnownCurrencies()
    local db = ns.GetDB()
    db.account.currencies = db.account.currencies or {}
    -- Tidy up: drop anything learned earlier that turns out to be reputation
    for id in pairs(db.account.currencies) do
        if ns.IsRepCurrency(id) then db.account.currencies[id] = nil end
    end
    return db.account.currencies
end

function ns.LearnCurrency(currencyID, name)
    if currencyID and name and not ns.IsRepCurrency(currencyID) then
        ns.GetDB().account.currencies = ns.GetDB().account.currencies or {}
        ns.GetDB().account.currencies[currencyID] = name
    end
end

-- Has this currency hit a limit? Returns "weekly", "full", or nil.
--   weekly = earned the most allowed this week
--   full   = holding (or have earned) the most allowed in total
function ns.CurrencyCap(currencyID)
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return nil end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
    if not ok or not info then return nil end

    local weeklyMax = info.maxWeeklyQuantity or 0
    if weeklyMax > 0 and (info.quantityEarnedThisWeek or 0) >= weeklyMax then
        return "weekly"
    end

    local max = info.maxQuantity or 0
    if max > 0 then
        local held = info.useTotalEarnedForMaxQty and (info.totalEarned or 0) or (info.quantity or 0)
        if held >= max then return "full" end
    end
    return nil
end

-- Is a category switched off? Currencies ("cur:1234") are off unless ticked.
function ns.IsCategoryOff(settings, category)
    local value = settings.off and settings.off[category]
    if category:sub(1, 4) == "cur:" then return value ~= false end
    return value == true
end

-- Make sure a saved priority list has every category exactly once.
-- New categories (future versions, newly seen currencies) join the bottom.
local function CleanPriority(list)
    local all = {}
    for _, c in ipairs(ns.DEFAULTS.priority) do table.insert(all, c) end
    local currencies = {}
    for id, name in pairs(ns.GetKnownCurrencies()) do
        table.insert(currencies, { key = "cur:" .. id, name = name })
    end
    table.sort(currencies, function(a, b) return a.name < b.name end)
    for _, c in ipairs(currencies) do table.insert(all, c.key) end

    local result, seen, valid = {}, {}, {}
    for _, c in ipairs(all) do valid[c] = true end
    for _, c in ipairs(list or {}) do
        if valid[c] and not seen[c] then table.insert(result, c); seen[c] = true end
    end
    for _, c in ipairs(all) do
        if not seen[c] then table.insert(result, c) end
    end
    return result
end

-- The settings that actually apply right now.
-- Everything is copied, so changing the result never edits the save file by accident.
function ns.GetSettings()
    local result = CopyTable(ns.DEFAULTS)
    local function Layer(source)
        for k, v in pairs(source) do
            result[k] = type(v) == "table" and CopyTable(v) or v
        end
    end
    Layer(ns.GetDB().account.settings)
    local char = ns.GetCharDB()
    if char.useOwn and char.settings then Layer(char.settings) end
    result.priority = CleanPriority(result.priority)
    return result
end
