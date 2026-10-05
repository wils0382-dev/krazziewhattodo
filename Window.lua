-- Krazzie - What to do : WINDOW
-- A movable panel showing the list. Drag to move, Esc or X to close.

local _, ns = ...
local Window = {}
ns.Window = Window

local WIDTH, HEIGHT, PAD = 440, 480, 12
local frame, scroll, content, summary
local lines = {}      -- text lines we reuse each time we redraw
local buttons = {}    -- tick/cross button pairs we reuse
local showAll = false

------------------------------------------------------------
-- Remember where you left the window (saved in KrazzieDB)
------------------------------------------------------------
local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint()
    KrazzieDB = KrazzieDB or {}
    KrazzieDB.window = { point = point, relPoint = relPoint, x = x, y = y }
end

local function RestorePosition()
    frame:ClearAllPoints()
    local pos = KrazzieDB and KrazzieDB.window
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER")
    end
end

------------------------------------------------------------
-- Build the window (only once, the first time it's opened)
------------------------------------------------------------
local function Create()
    frame = CreateFrame("Frame", "KrazzieWindow", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(unpack(ns.THEME.background))
    frame:SetBackdropBorderColor(unpack(ns.THEME.border))

    -- Drag to move
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    -- Esc closes it
    tinsert(UISpecialFrames, "KrazzieWindow")

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("|cffff9900Krazzie|r - What to do")

    -- X button
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    -- Refresh button
    local refresh = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refresh:SetSize(70, 22)
    refresh:SetPoint("TOPRIGHT", -30, -8)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function() Window:Refresh() end)

    -- Settings button (opens the panel beside the window)
    local settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    settingsButton:SetSize(70, 22)
    settingsButton:SetPoint("RIGHT", refresh, "LEFT", -4, 0)
    settingsButton:SetText("Settings")
    settingsButton:SetScript("OnClick", function() ns.SettingsPanel:Toggle(frame) end)

    -- "Show everything" tick box
    local box = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    box:SetSize(22, 22)
    box:SetPoint("TOPLEFT", PAD - 4, -38)
    box:SetScript("OnClick", function(self)
        showAll = self:GetChecked()
        Window:Refresh()
    end)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", box, "RIGHT", 2, 0)
    label:SetText("Show everything (skipped quests greyed out)")

    -- Scrolling list area (scroll with the mouse wheel)
    scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", PAD, -66)
    scroll:SetPoint("BOTTOMRIGHT", -PAD, 34)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - PAD * 2, 1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local value = self:GetVerticalScroll() - delta * 40
        value = math.max(0, math.min(value, self:GetVerticalScrollRange()))
        self:SetVerticalScroll(value)
    end)

    -- Summary line along the bottom
    summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summary:SetPoint("BOTTOMLEFT", PAD, PAD)
    summary:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    summary:SetJustifyH("LEFT")

    RestorePosition()
    frame:Hide()
end

------------------------------------------------------------
-- Tick and cross buttons
------------------------------------------------------------
local function MakeIconButton(texture, tip)
    local b = CreateFrame("Button", nil, content)
    b:SetSize(14, 14)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(texture)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tip)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function GetButtons(i)
    if not buttons[i] then
        buttons[i] = {
            yes = MakeIconButton("Interface\\RaidFrame\\ReadyCheck-Ready",
                "Always show this quest\n|cff888888Click again to undo|r"),
            no  = MakeIconButton("Interface\\RaidFrame\\ReadyCheck-NotReady",
                "Hide this quest on this character\n|cff888888Click again to undo|r"),
        }
    end
    return buttons[i]
end

------------------------------------------------------------
-- Draw the list
------------------------------------------------------------
local function GetLine(i)
    if not lines[i] then
        local fs = content:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        lines[i] = fs
    end
    return lines[i]
end

function Window:Render(result, keepScroll)
    local savedScroll = scroll:GetVerticalScroll()
    for _, fs in ipairs(lines) do fs:Hide() end
    for _, b in ipairs(buttons) do b.yes:Hide(); b.no:Hide() end
    local width = WIDTH - PAD * 2
    local y, count, questCount = 0, 0, 0

    local function Add(text, indent, font)
        count = count + 1
        local fs = GetLine(count)
        fs:SetFontObject(font)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", indent, -y)
        fs:SetWidth(width - indent)
        fs:SetText(text)
        fs:Show()
        y = y + fs:GetStringHeight() + 4
    end

    local lastZone, shown = nil, 0
    for _, e in ipairs(result.entries) do
        if e.rank or showAll then
            if e.zoneID ~= lastZone then
                lastZone = e.zoneID
                if shown > 0 then y = y + 8 end -- gap between zones
                Add(ns.ZoneName(e.zoneID), 0, "GameFontNormal")
            end
            if e.isQuest then
                -- Tick and cross on the left, text after them
                questCount = questCount + 1
                local b = GetButtons(questCount)
                local questID = e.questID
                b.yes:ClearAllPoints()
                b.yes:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -y)
                b.no:ClearAllPoints()
                b.no:SetPoint("LEFT", b.yes, "RIGHT", 4, 0)
                -- Bright = chosen, faded = not chosen
                b.yes:SetAlpha(e.choice == "yes" and 1 or 0.3)
                b.no:SetAlpha(e.choice == "no" and 1 or 0.3)
                b.yes:SetScript("OnClick", function() ns.SetChoice(questID, "yes"); Window:Refresh(true) end)
                b.no:SetScript("OnClick", function() ns.SetChoice(questID, "no"); Window:Refresh(true) end)
                b.yes:Show()
                b.no:Show()
                Add(ns.FormatLine(e), 46, "GameFontHighlightSmall")
            else
                Add(ns.FormatLine(e), 46, "GameFontHighlightSmall")
            end
            shown = shown + 1
        end
    end
    if shown == 0 then
        Add("Nothing worth doing right now. Tick 'Show everything' to see all quests.", 0, "GameFontHighlightSmall")
    end

    content:SetHeight(math.max(y, 1))
    if keepScroll then
        -- Stay where you were (wait one frame for the new height to settle)
        C_Timer.After(0, function()
            scroll:SetVerticalScroll(math.min(savedScroll, scroll:GetVerticalScrollRange()))
        end)
    else
        scroll:SetVerticalScroll(0)
    end
    summary:SetText(ns.SummaryText(result))
end

------------------------------------------------------------
-- Public: open, toggle, refresh
------------------------------------------------------------
function Window:Refresh(keepScroll)
    if not frame then Create() end
    summary:SetText("Scanning...")
    ns.Scan(function(result) Window:Render(result, keepScroll) end)
end

function Window:Open()
    if not frame then Create() end
    frame:Show()
    Window:Refresh()
end

function Window:Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        Window:Open()
    end
end
