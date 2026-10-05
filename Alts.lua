-- Krazzie - What to do : ALTS
-- Each character saves a snapshot after every scan. The Alts panel
-- (below the main window) shows them all and suggests who to play next.

local _, ns = ...
local Alts = {}
ns.Alts = Alts

local PAD = 12
local panel, lines = nil, {}

------------------------------------------------------------
-- Saving and reading snapshots
------------------------------------------------------------
function ns.SaveSnapshot(result)
    local _, class = UnitClass("player")
    ns.GetCharDB().snapshot = {
        worth  = result.worth,
        ready  = result.ready,
        locked = result.locked,
        handIn = result.handIn or 0,
        time   = time(),
        class  = class,
    }
    if panel and panel:IsShown() then Alts:Update() end
end

-- "12 min ago", "3 h ago", "2 days ago"
local function Age(savedAt)
    local seconds = time() - (savedAt or 0)
    if seconds < 3600 then return math.max(1, math.floor(seconds / 60)) .. " min ago" end
    if seconds < 86400 then return math.floor(seconds / 3600) .. " h ago" end
    return math.floor(seconds / 86400) .. " days ago"
end

-- Character name (without realm) in its class colour
local function ColouredName(key, class)
    local name = key:match("^(.-)%-") or key
    local colour = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if colour and colour.colorStr then return "|c" .. colour.colorStr .. name .. "|r" end
    return name
end

-- Every character with a snapshot, most to do first
function ns.GetAltSummaries()
    local list = {}
    for key, char in pairs(ns.GetDB().chars) do
        if char.snapshot then table.insert(list, { key = key, snap = char.snapshot }) end
    end
    table.sort(list, function(a, b)
        local wa = a.snap.worth + (a.snap.handIn or 0)
        local wb = b.snap.worth + (b.snap.handIn or 0)
        if wa ~= wb then return wa > wb end
        return a.key < b.key
    end)
    return list
end

function ns.AltLine(entry)
    local s = entry.snap
    local parts = {}
    table.insert(parts, s.worth > 0 and (s.worth .. " to do") or "|cff00ff00done|r")
    if (s.ready or 0) > 0 then table.insert(parts, "|cffa335ee" .. s.ready .. " SA ready|r") end
    if (s.handIn or 0) > 0 then table.insert(parts, "|cff00ff00" .. s.handIn .. " to hand in|r") end
    local you = (entry.key == ns.CharKey()) and " |cffaaaaaa(you)|r" or ""
    return ("%s%s - %s  |cff888888%s|r"):format(ColouredName(entry.key, s.class), you,
        table.concat(parts, ", "), Age(s.time))
end

-- The best character to play next (not the one you're on)
function ns.SuggestNext()
    for _, e in ipairs(ns.GetAltSummaries()) do
        if e.key ~= ns.CharKey() and (e.snap.worth > 0 or (e.snap.handIn or 0) > 0) then
            return e
        end
    end
end

------------------------------------------------------------
-- The panel
------------------------------------------------------------
local function Create(parent)
    panel = CreateFrame("Frame", "KrazzieAltsPanel", parent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(unpack(ns.THEME.background))
    panel:SetBackdropBorderColor(unpack(ns.THEME.border))
    panel:EnableMouse(true)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("Characters")
    panel:Hide()
end

local function GetLine(i)
    if not lines[i] then
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        lines[i] = fs
    end
    return lines[i]
end

function Alts:Update()
    if not panel then return end
    for _, fs in ipairs(lines) do fs:Hide() end
    local y, count = -38, 0
    local function Add(text, font, gap)
        count = count + 1
        local fs = GetLine(count)
        fs:SetFontObject(font or "GameFontHighlightSmall")
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", PAD, y)
        fs:SetPoint("RIGHT", -PAD, 0)
        fs:SetText(text)
        fs:Show()
        y = y - fs:GetStringHeight() - (gap or 5)
    end

    local nextUp = ns.SuggestNext()
    if nextUp then
        Add("Next up: " .. ns.AltLine(nextUp), "GameFontNormal", 10)
    else
        Add("|cff00ff00Everyone's done, as far as Krazzie knows.|r", "GameFontNormal", 10)
    end
    for _, entry in ipairs(ns.GetAltSummaries()) do Add(ns.AltLine(entry)) end
    Add("|cff888888Counts are from each character's last scan. Log onto a character to update it.|r", nil, 0)

    panel:SetHeight(-y + PAD)
end

-- Opens below the main window, or above it if there's no room below
function Alts:Toggle(parent)
    if not panel then Create(parent) end
    if panel:IsShown() then panel:Hide() return end
    panel:ClearAllPoints()
    if (parent:GetBottom() or 0) < 220 then
        panel:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, 4)
        panel:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, 4)
    else
        panel:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -4)
        panel:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, -4)
    end
    panel:Show()
    Alts:Update()
end
