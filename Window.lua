-- Krazzie - What to do : WINDOW
-- A movable, resizable panel showing the list.
-- Drag the title area to move, drag the bottom-right corner to resize,
-- click a zone heading to collapse or expand it.

local _, ns = ...
local Window = {}
ns.Window = Window

local DEFAULT_WIDTH, DEFAULT_HEIGHT, PAD = 440, 480, 12
local frame, scroll, content, summary
local lines, buttons, headers = {}, {}, {} -- pieces we reuse each redraw
local showAll = false
local lastResult                            -- last scan, so we can redraw without rescanning

-- In "focus" mode, clicking a heading flips it only until you change zone
local overrides, overrideZone = {}, nil

------------------------------------------------------------
-- Remember position and size (saved in KrazzieDB.window)
------------------------------------------------------------
local function SaveLayout()
    local point, _, relPoint, x, y = frame:GetPoint()
    ns.GetDB().window = {
        point = point, relPoint = relPoint, x = x, y = y,
        width = frame:GetWidth(), height = frame:GetHeight(),
    }
end

local function RestoreLayout()
    local saved = ns.GetDB().window
    frame:ClearAllPoints()
    if saved then
        frame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
        frame:SetSize(saved.width or DEFAULT_WIDTH, saved.height or DEFAULT_HEIGHT)
    else
        frame:SetPoint("CENTER")
        frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    end
end

------------------------------------------------------------
-- Settings that affect the window itself
------------------------------------------------------------
function Window:ApplySettings()
    if not frame then return end
    -- Take ourselves off the game's "close on Esc" list, then add back if wanted
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "KrazzieWindow" then table.remove(UISpecialFrames, i) end
    end
    if ns.GetSettings().closeOnEscape then
        tinsert(UISpecialFrames, "KrazzieWindow")
    end
end

------------------------------------------------------------
-- Collapsing zones
------------------------------------------------------------
-- The Midnight zone you're standing in (climbs up from caves, buildings, etc.)
local function GetCurrentZone()
    return ns.GetCurrentZone() -- lives in Scanner.lua
end

-- Headings are keyed by zone ID (a number) or a name like "weekly" or "event:Brewfest".
-- "Focus on my current zone" only affects zone headings.
local function IsExpanded(zoneID)
    if ns.GetSettings().focusCurrentZone and type(zoneID) == "number" then
        local current = GetCurrentZone()
        if current ~= overrideZone then -- you've moved zone: forget temporary flips
            overrides, overrideZone = {}, current
        end
        if overrides[zoneID] ~= nil then return overrides[zoneID] end
        if not current then return true end -- outside Midnight: show everything
        return zoneID == current
    end
    local collapsed = ns.GetCharDB().collapsed
    return not (collapsed and collapsed[zoneID])
end

local function ToggleZone(zoneID)
    local expanded = IsExpanded(zoneID)
    if ns.GetSettings().focusCurrentZone and type(zoneID) == "number" then
        overrides[zoneID] = not expanded
    else
        local char = ns.GetCharDB()
        char.collapsed = char.collapsed or {}
        char.collapsed[zoneID] = expanded or nil -- remembered per character
    end
    Window:Render(lastResult, true)
end

------------------------------------------------------------
-- Build the window (only once)
------------------------------------------------------------
local function Create()
    frame = CreateFrame("Frame", "KrazzieWindow", UIParent, "BackdropTemplate")
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
        SaveLayout()
    end)

    -- Resizing: min and max sizes, plus a grab handle in the corner
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(400, 240, 1000, 1200)
    end
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SaveLayout()
    end)
    -- Redraw as the size changes, so text re-wraps to the new width
    frame:SetScript("OnSizeChanged", function()
        if lastResult then Window:Render(lastResult, true) end
    end)

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

    -- Settings button
    local settingsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    settingsButton:SetSize(70, 22)
    settingsButton:SetPoint("RIGHT", refresh, "LEFT", -4, 0)
    settingsButton:SetText("Settings")
    settingsButton:SetScript("OnClick", function() ns.SettingsPanel:Toggle(frame) end)

    -- Alts button
    local altsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    altsButton:SetSize(50, 22)
    altsButton:SetPoint("RIGHT", settingsButton, "LEFT", -4, 0)
    altsButton:SetText("Alts")
    altsButton:SetScript("OnClick", function() ns.Alts:Toggle(frame) end)

    -- "Show everything" tick box
    local box = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    box:SetSize(22, 22)
    box:SetPoint("TOPLEFT", PAD - 4, -38)
    box:SetScript("OnClick", function(self)
        showAll = self:GetChecked()
        Window:Refresh(true)
    end)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", box, "RIGHT", 2, 0)
    label:SetText("Show everything (skipped quests greyed out)")

    -- Scrolling list area (scroll with the mouse wheel)
    scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", PAD, -66)
    scroll:SetPoint("BOTTOMRIGHT", -PAD, 34)
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(DEFAULT_WIDTH - PAD * 2, 1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local value = self:GetVerticalScroll() - delta * 40
        value = math.max(0, math.min(value, self:GetVerticalScrollRange()))
        self:SetVerticalScroll(value)
    end)

    -- Summary line along the bottom (leaves room for the resize handle)
    summary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summary:SetPoint("BOTTOMLEFT", PAD, PAD)
    summary:SetPoint("BOTTOMRIGHT", -PAD - 16, PAD)
    summary:SetJustifyH("LEFT")

    RestoreLayout()
    Window:ApplySettings()
    frame:Hide()
end

------------------------------------------------------------
-- Reusable pieces: text lines, tick/cross buttons, zone headings
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

local function GetHeader(i)
    if not headers[i] then
        local h = CreateFrame("Button", nil, content)
        h:SetHeight(18)
        h.icon = h:CreateTexture(nil, "ARTWORK")
        h.icon:SetSize(12, 12)
        h.icon:SetPoint("LEFT", 0, 0)
        h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h.text:SetPoint("LEFT", h.icon, "RIGHT", 4, 0)
        h.text:SetJustifyH("LEFT")
        h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        headers[i] = h
    end
    return headers[i]
end

------------------------------------------------------------
-- Draw the list
------------------------------------------------------------
function Window:Render(result, keepScroll)
    if not result or not frame then return end
    lastResult = result
    local savedScroll = scroll:GetVerticalScroll()
    local settings = result.settings or ns.GetSettings()

    for _, fs in ipairs(lines) do fs:Hide() end
    for _, b in ipairs(buttons) do b.yes:Hide(); b.no:Hide() end
    for _, h in ipairs(headers) do h:Hide() end

    local width = scroll:GetWidth()
    if not width or width < 50 then width = frame:GetWidth() - PAD * 2 end
    content:SetWidth(width)
    local y, lineCount, questCount, headerCount, shownSomething = 0, 0, 0, 0, false

    local function Add(text, indent, font)
        lineCount = lineCount + 1
        local fs = GetLine(lineCount)
        fs:SetFontObject(font or "GameFontHighlightSmall")
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", content, "TOPLEFT", indent, -y)
        fs:SetWidth(width - indent)
        fs:SetText(text)
        fs:Show()
        y = y + fs:GetStringHeight() + 4
    end

    -- A clickable heading. Returns true if its section is expanded.
    -- countText shows beside the name while collapsed, e.g. "(4)"
    local function Heading(key, name, countText)
        if shownSomething then y = y + 6 end
        shownSomething = true
        local expanded = IsExpanded(key)
        headerCount = headerCount + 1
        local h = GetHeader(headerCount)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        h:SetWidth(width)
        h.icon:SetTexture(expanded and "Interface\\Buttons\\UI-MinusButton-Up"
                                    or "Interface\\Buttons\\UI-PlusButton-Up")
        h.text:SetText(name .. ((not expanded and countText) and ("  |cffaaaaaa" .. countText .. "|r") or ""))
        h:SetScript("OnClick", function() ToggleZone(key) end)
        h:Show()
        y = y + 20
        return expanded
    end

    -- SECTION: weekly quests from your quest log
    local function DrawWeekly()
        local weeklies = result.weeklies or {}
        if #weeklies == 0 then return end
        local handIn = result.handIn or 0
        if Heading("weekly", "This week", "(" .. (handIn > 0 and (handIn .. " to hand in") or #weeklies) .. ")") then
            for _, w in ipairs(weeklies) do Add(ns.FormatWeekly(w), 16) end
        end
    end

    -- SECTION: this week's activities (bountiful delves, events, ritual sites)
    local function DrawActivities()
        local acts = result.activities
        if not acts or #acts.list == 0 then return end
        local open = 0
        for _, a in ipairs(acts.list) do
            if a.choice ~= "no" then open = open + 1 end
        end
        if not Heading("activities", "This week's activities", "(" .. open .. ")") then return end
        if acts.keys then
            Add(("|cffaaaaaaRestored Coffer Keys: |r%d"):format(acts.keys), 16)
        end
        for _, a in ipairs(acts.list) do
            if a.choice ~= "no" or showAll then
                questCount = questCount + 1
                local b = GetButtons(questCount)
                local key = a.key
                b.yes:ClearAllPoints()
                b.yes:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -y)
                b.no:ClearAllPoints()
                b.no:SetPoint("LEFT", b.yes, "RIGHT", 4, 0)
                b.yes:SetAlpha(a.choice == "yes" and 1 or 0.3)
                b.no:SetAlpha(a.choice == "no" and 1 or 0.3)
                b.yes:SetScript("OnClick", function() ns.Activities:SetChoice(key, "yes"); Window:Refresh(true) end)
                b.no:SetScript("OnClick", function() ns.Activities:SetChoice(key, "no"); Window:Refresh(true) end)
                b.yes:Show()
                b.no:Show()
                Add(ns.Activities:Format(a), 46)
            end
        end
    end

    -- SECTION: running events (from All The Things), one line per activity
    local function DrawEvents()
        for _, event in ipairs(result.events or {}) do
            local eventLines = ns.Events:Lines(event, settings)
            if #eventLines > 0 then
                local open = 0
                for _, text in ipairs(eventLines) do
                    if not text:find("(done today)", 1, true) then open = open + 1 end
                end
                if Heading("event:" .. event.name, event.name .. "  |cffaaaaaa(event)|r", "(" .. open .. ")") then
                    for _, text in ipairs(eventLines) do Add(text, 16) end
                end
            end
        end
    end

    -- SECTION: world quests, grouped by zone
    local function DrawZones()
        local zones, byZone = {}, {}
        for _, e in ipairs(result.entries) do
            if e.rank or showAll then
                if not byZone[e.zoneID] then
                    byZone[e.zoneID] = {}
                    table.insert(zones, e.zoneID)
                end
                table.insert(byZone[e.zoneID], e)
            end
        end

        for _, zoneID in ipairs(zones) do
            local list = byZone[zoneID]
            local worth = 0
            for _, e in ipairs(list) do
                if e.isQuest and e.rank then worth = worth + 1 end
            end
            if Heading(zoneID, ns.ZoneName(zoneID), "(" .. worth .. ")") then
                for _, e in ipairs(list) do
                    if e.isQuest then
                        questCount = questCount + 1
                        local b = GetButtons(questCount)
                        local questID = e.questID
                        b.yes:ClearAllPoints()
                        b.yes:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -y)
                        b.no:ClearAllPoints()
                        b.no:SetPoint("LEFT", b.yes, "RIGHT", 4, 0)
                        b.yes:SetAlpha(e.choice == "yes" and 1 or 0.3) -- bright = chosen
                        b.no:SetAlpha(e.choice == "no" and 1 or 0.3)
                        b.yes:SetScript("OnClick", function() ns.SetChoice(questID, "yes"); Window:Refresh(true) end)
                        b.no:SetScript("OnClick", function() ns.SetChoice(questID, "no"); Window:Refresh(true) end)
                        b.yes:Show()
                        b.no:Show()
                    end
                    Add(ns.FormatLine(e), 46)
                end
            end
        end
    end

    -- Draw the sections in your chosen order
    local DRAW = { weekly = DrawWeekly, activities = DrawActivities, zones = DrawZones, events = DrawEvents }
    for _, section in ipairs(settings.sectionOrder or { "weekly", "activities", "zones", "events" }) do
        if DRAW[section] then DRAW[section]() end
    end

    if not shownSomething then
        Add("Nothing worth doing right now. Tick 'Show everything' to see all quests.", 0)
    end

    content:SetHeight(math.max(y, 1))
    if keepScroll then
        C_Timer.After(0, function() -- wait one frame for the new height to settle
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

function Window:OpenSettings()
    Window:Open()
    ns.SettingsPanel:Toggle(frame)
end

-- Redraw from the last scan without rescanning (e.g. token counts changed)
function Window:Redraw()
    if frame and frame:IsShown() and lastResult then Window:Render(lastResult, true) end
end

function Window:IsShown()
    return frame ~= nil and frame:IsShown()
end

function Window:Toggle()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        Window:Open()
    end
end

-- When you change zone, redraw so "focus on my current zone" follows you
local zoneWatcher = CreateFrame("Frame")
zoneWatcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zoneWatcher:SetScript("OnEvent", function()
    if frame and frame:IsShown() and lastResult and ns.GetSettings().focusCurrentZone then
        Window:Render(lastResult, true)
    end
end)
