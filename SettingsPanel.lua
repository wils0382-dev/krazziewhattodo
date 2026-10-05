-- Krazzie - What to do : SETTINGS PANEL
-- The panel that opens beside the main window from its Settings button.

local _, ns = ...
local Panel = {}
ns.SettingsPanel = Panel

local WIDTH, PAD = 270, 12
local LABELS = {
    pick   = "Your picks (ticked quests)",
    gear   = "Gear upgrades",
    gold   = "Gold",
    sa     = "Special Assignments",
    unlock = "Unlocks a Special Assignment",
}

local panel, ownBox, scopeText, goldBox, ilvlBox, loginBox, chatBox
local rows = {}

------------------------------------------------------------
-- After any change: redraw this panel and refresh the list
------------------------------------------------------------
local function Changed()
    Panel:Update()
    ns.Window:Refresh(true)
end

------------------------------------------------------------
-- Little building blocks
------------------------------------------------------------
local function Label(text, x, y, font)
    local fs = panel:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function TickBox(text, y, onClick)
    local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    box:SetSize(22, 22)
    box:SetPoint("TOPLEFT", PAD - 4, y)
    box:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", box, "RIGHT", 2, 0)
    fs:SetText(text)
    return box
end

-- A small typing box for whole numbers. Saves when you press Enter or click away.
local function NumberBox(text, y, key)
    Label(text, PAD, y - 4)
    local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    box:SetSize(60, 20)
    box:SetPoint("TOPRIGHT", -PAD - 4, y)
    box:SetAutoFocus(false) -- don't grab the keyboard when the panel opens
    box:SetNumeric(true)
    local function Apply(self)
        local value = tonumber(self:GetText())
        if value then ns.SetSetting(key, value) end
        Changed()
    end
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", Apply)
    return box
end

-- Move a priority category up (-1) or down (+1)
local function MovePriority(index, direction)
    local list = ns.GetSettings().priority
    local other = index + direction
    if other < 1 or other > #list then return end
    list[index], list[other] = list[other], list[index]
    ns.SetSetting("priority", list)
    Changed()
end

local function ArrowButton(texture, onClick)
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(20, 20)
    b:SetNormalTexture(texture .. "-Up")
    b:SetPushedTexture(texture .. "-Down")
    b:SetDisabledTexture(texture .. "-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnClick", onClick)
    return b
end

------------------------------------------------------------
-- Build the panel (once)
------------------------------------------------------------
local function Create(parent)
    panel = CreateFrame("Frame", "KrazzieSettingsPanel", parent, "BackdropTemplate")
    panel:SetSize(WIDTH, parent:GetHeight())
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(unpack(ns.THEME.background))
    panel:SetBackdropBorderColor(unpack(ns.THEME.border))
    panel:EnableMouse(true)

    Label("Settings", PAD, -PAD, "GameFontNormalLarge")

    -- Who these settings apply to
    ownBox = TickBox("Separate settings for this character", -40, function(on)
        ns.SetUseOwn(on)
        Changed()
    end)
    scopeText = Label("", PAD, -66, "GameFontDisableSmall")
    scopeText:SetWidth(WIDTH - PAD * 2)

    -- Thresholds
    Label("Rules", PAD, -92, "GameFontNormal")
    goldBox = NumberBox("Minimum gold to flag", -112, "minGold")
    ilvlBox = NumberBox("Minimum item level upgrade", -138, "minUpgrade")

    -- Priority order
    Label("Priority (top shows first)", PAD, -172, "GameFontNormal")
    for i = 1, #ns.DEFAULTS.priority do
        local y = -192 - (i - 1) * 24
        local row = {}
        row.number = Label(i .. ".", PAD, y - 4)
        row.text = Label("", PAD + 16, y - 4)
        row.up = ArrowButton("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp", function() MovePriority(i, -1) end)
        row.up:SetPoint("TOPRIGHT", -PAD - 22, y)
        row.down = ArrowButton("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown", function() MovePriority(i, 1) end)
        row.down:SetPoint("TOPRIGHT", -PAD, y)
        rows[i] = row
    end

    -- Login behaviour
    local y = -192 - #ns.DEFAULTS.priority * 24 - 12
    Label("On login", PAD, y, "GameFontNormal")
    loginBox = TickBox("Open this window", y - 20, function(on)
        ns.SetSetting("openOnLogin", on and true or false)
        Changed()
    end)
    chatBox = TickBox("Also print the list to chat", y - 44, function(on)
        ns.SetSetting("chatOnLogin", on and true or false)
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

    for i, row in ipairs(rows) do
        row.text:SetText(LABELS[s.priority[i]] or s.priority[i])
        row.up:SetEnabled(i > 1)
        row.down:SetEnabled(i < #rows)
    end

    loginBox:SetChecked(s.openOnLogin)
    chatBox:SetChecked(s.chatOnLogin)
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
