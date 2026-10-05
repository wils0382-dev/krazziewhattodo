-- Krazzie - What to do : SETTINGS PANEL
-- The panel that opens beside the main window from its Settings button.

local _, ns = ...
local Panel = {}
ns.SettingsPanel = Panel

local WIDTH, PAD, ROW = 300, 12, 22
local PRIORITY_TOP = 192   -- where the priority list starts
local LOWER_HEIGHT = 194   -- height of the "On login" + "Window" sections

local LABELS = {
    pick    = "Your picks (ticked quests)",
    gear    = "Gear upgrades",
    gold    = "Gold",
    sa      = "Special Assignments",
    unlock  = "Unlocks a Special Assignment",
    anygear = "Any gear (e.g. to disenchant)",
    rep     = "Reputation (all factions)",
}

local panel, prioFrame, lower
local ownBox, scopeText, goldBox, ilvlBox, loginBox, chatBox, escBox, focusBox, minimapBox, weeklyBox
local rows = {}

-- Friendly name for a category, including learned currencies
function ns.CategoryLabel(category)
    if LABELS[category] then return LABELS[category] end
    local id = tonumber(category:match("^cur:(%d+)$"))
    if id then return ns.GetKnownCurrencies()[id] or ("Currency " .. id) end
    return category
end

------------------------------------------------------------
-- After any change: redraw this panel and refresh everything
------------------------------------------------------------
local function Changed()
    Panel:Update()
    ns.Window:ApplySettings()
    ns.Broker:ApplySettings()
    ns.Window:Refresh(true)
end

------------------------------------------------------------
-- Little building blocks
------------------------------------------------------------
local function Label(parent, text, x, y, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function TickBox(parent, text, x, y, onClick)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(22, 22)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
    box.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.label:SetPoint("LEFT", box, "RIGHT", 2, 0)
    box.label:SetText(text)
    return box
end

-- A small typing box for whole numbers. Saves when you press Enter or click away.
local function NumberBox(text, y, key)
    Label(panel, text, PAD, y - 4)
    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(60, 20)
    box:SetPoint("TOPRIGHT", -PAD - 4, y)
    box:SetAutoFocus(false) -- don't grab the keyboard when the panel opens
    box:SetNumeric(true)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self)
        local value = tonumber(self:GetText())
        if value then ns.SetSetting(key, value) end
        Changed()
    end)
    return box
end

local function ArrowButton(parent, texture)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    b:SetNormalTexture(texture .. "-Up")
    b:SetPushedTexture(texture .. "-Down")
    b:SetDisabledTexture(texture .. "-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    return b
end

------------------------------------------------------------
-- Priority list actions
------------------------------------------------------------
local function MovePriority(index, direction)
    local list = ns.GetSettings().priority
    local other = index + direction
    if other < 1 or other > #list then return end
    list[index], list[other] = list[other], list[index]
    ns.SetSetting("priority", list)
    Changed()
end

local function SetCategoryOn(category, on)
    local off = ns.GetSettings().off or {}
    if category:sub(1, 4) == "cur:" then
        off[category] = not on      -- currencies: false = ticked on
    else
        off[category] = (not on) or nil
    end
    ns.SetSetting("off", off)
    Changed()
end

-- One row: tick box, number and name, up/down arrows
local function GetRow(i)
    if not rows[i] then
        local row = CreateFrame("Frame", nil, prioFrame)
        row:SetSize(WIDTH - PAD * 2, ROW)
        row.box = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.box:SetSize(20, 20)
        row.box:SetPoint("LEFT", -4, 0)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.box, "RIGHT", 2, 0)
        row.text:SetPoint("RIGHT", -46, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row.down = ArrowButton(row, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown")
        row.down:SetPoint("RIGHT", 0, 0)
        row.up = ArrowButton(row, "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp")
        row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
        rows[i] = row
    end
    return rows[i]
end

------------------------------------------------------------
-- Build the panel (once)
------------------------------------------------------------
local function Create(parent)
    panel = CreateFrame("Frame", "KrazzieSettingsPanel", parent, "BackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(unpack(ns.THEME.background))
    panel:SetBackdropBorderColor(unpack(ns.THEME.border))
    panel:EnableMouse(true)

    Label(panel, "Settings", PAD, -PAD, "GameFontNormalLarge")

    -- Who these settings apply to
    ownBox = TickBox(panel, "Separate settings for this character", PAD - 4, -40, function(on)
        ns.SetUseOwn(on)
        Changed()
    end)
    scopeText = Label(panel, "", PAD, -66, "GameFontDisableSmall")
    scopeText:SetWidth(WIDTH - PAD * 2)

    -- Thresholds
    Label(panel, "Rules", PAD, -92, "GameFontNormal")
    goldBox = NumberBox("Minimum gold to flag", -112, "minGold")
    ilvlBox = NumberBox("Minimum item level upgrade", -138, "minUpgrade")

    -- Priority list (rows are drawn in Update, because currencies can be added)
    Label(panel, "Priority (tick = on, top shows first)", PAD, -172, "GameFontNormal")
    prioFrame = CreateFrame("Frame", nil, panel)
    prioFrame:SetPoint("TOPLEFT", PAD, -PRIORITY_TOP)
    prioFrame:SetSize(WIDTH - PAD * 2, ROW)

    -- Everything below the priority list moves down as the list grows
    lower = CreateFrame("Frame", nil, panel)
    lower:SetPoint("TOPLEFT", prioFrame, "BOTTOMLEFT", 0, -12)
    lower:SetSize(WIDTH - PAD * 2, LOWER_HEIGHT)

    Label(lower, "On login", 0, 0, "GameFontNormal")
    loginBox = TickBox(lower, "Open this window", -4, -20, function(on)
        ns.SetSetting("openOnLogin", on and true or false)
        Changed()
    end)
    chatBox = TickBox(lower, "Also print the list to chat", -4, -44, function(on)
        ns.SetSetting("chatOnLogin", on and true or false)
        Changed()
    end)

    Label(lower, "Window", 0, -78, "GameFontNormal")
    escBox = TickBox(lower, "Close with Esc (and when the map opens)", -4, -98, function(on)
        ns.SetSetting("closeOnEscape", on and true or false)
        Changed()
    end)
    focusBox = TickBox(lower, "Focus on my current zone", -4, -122, function(on)
        ns.SetSetting("focusCurrentZone", on and true or false)
        Changed()
    end)
    minimapBox = TickBox(lower, "Show minimap button", -4, -146, function(on)
        ns.SetSetting("showMinimap", on and true or false)
        Changed()
    end)
    weeklyBox = TickBox(lower, "Show weekly quests from my quest log", -4, -170, function(on)
        ns.SetSetting("showWeeklies", on and true or false)
        Changed()
    end)

    -- Reset
    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(130, 22)
    reset:SetPoint("BOTTOMLEFT", PAD, PAD)
    reset:SetText("Reset to defaults")
    reset:SetScript("OnClick", function()
        ns.ResetActive()
        Changed()
    end)

    panel:Hide()
end

------------------------------------------------------------
-- Fill the panel with the current values
------------------------------------------------------------
function Panel:Update()
    if not panel then return end
    local s = ns.GetSettings()
    local own = ns.UsesOwnSettings()

    ownBox:SetChecked(own)
    scopeText:SetText(own
        and ("Changes below apply to " .. UnitName("player") .. " only.")
        or "Changes below apply to all characters.")

    if not goldBox:HasFocus() then goldBox:SetText(tostring(s.minGold)) end
    if not ilvlBox:HasFocus() then ilvlBox:SetText(tostring(s.minUpgrade)) end

    -- Priority rows
    for _, row in ipairs(rows) do row:Hide() end
    local count = #s.priority
    for i, category in ipairs(s.priority) do
        local row = GetRow(i)
        local isOn = not ns.IsCategoryOff(s, category)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", prioFrame, "TOPLEFT", 0, -(i - 1) * ROW)
        row.box:SetChecked(isOn)
        row.box:SetScript("OnClick", function(self) SetCategoryOn(category, self:GetChecked()) end)
        row.text:SetText(i .. ". " .. ns.CategoryLabel(category))
        row.text:SetTextColor(isOn and 1 or 0.5, isOn and 1 or 0.5, isOn and 1 or 0.5) -- grey when off
        row.up:SetEnabled(i > 1)
        row.down:SetEnabled(i < count)
        row.up:SetScript("OnClick", function() MovePriority(i, -1) end)
        row.down:SetScript("OnClick", function() MovePriority(i, 1) end)
        row:Show()
    end
    prioFrame:SetHeight(math.max(count * ROW, 1))
    panel:SetHeight(PRIORITY_TOP + count * ROW + 12 + LOWER_HEIGHT + 44)

    loginBox:SetChecked(s.openOnLogin)
    chatBox:SetChecked(s.chatOnLogin)
    escBox:SetChecked(s.closeOnEscape)
    focusBox:SetChecked(s.focusCurrentZone)
    minimapBox:SetChecked(s.showMinimap)
    weeklyBox:SetChecked(s.showWeeklies)
end

------------------------------------------------------------
-- Open/close, on whichever side of the window has room
------------------------------------------------------------
function Panel:Toggle(parent)
    if not panel then Create(parent) end
    if panel:IsShown() then
        panel:Hide()
        return
    end
    panel:ClearAllPoints()
    if (parent:GetRight() or 0) + WIDTH + 10 > UIParent:GetWidth() then
        panel:SetPoint("TOPRIGHT", parent, "TOPLEFT", -4, 0)
    else
        panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", 4, 0)
    end
    Panel:Update()
    panel:Show()
end
