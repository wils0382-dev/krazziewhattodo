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

-- Make sure a saved priority list has every category exactly once
-- (protects old saves if new categories are added in future versions)
local function CleanPriority(list)
    local result, seen, valid = {}, {}, {}
    for _, c in ipairs(ns.DEFAULTS.priority) do valid[c] = true end
    for _, c in ipairs(list or {}) do
        if valid[c] and not seen[c] then table.insert(result, c); seen[c] = true end
    end
    for _, c in ipairs(ns.DEFAULTS.priority) do
        if not seen[c] then table.insert(result, c) end
    end
    return result
end

-- The settings that actually apply right now
function ns.GetSettings()
    local result = CopyTable(ns.DEFAULTS)
    for k, v in pairs(ns.GetDB().account.settings) do result[k] = v end
    local char = ns.GetCharDB()
    if char.useOwn and char.settings then
        for k, v in pairs(char.settings) do result[k] = v end
    end
    result.priority = CleanPriority(result.priority)
    return result
end
