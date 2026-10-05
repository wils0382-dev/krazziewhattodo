-- Krazzie - What to do : CHOICES
-- Remembers your tick (yes) and cross (no) on each quest, per character.
-- Each choice clears itself when that quest expires.

local _, ns = ...

-- This character's own section of the save file, e.g. KrazzieDB.chars["Krazzie-Frostmourne"]
local function GetChoices()
    local char = ns.GetCharDB() -- from Profile.lua
    char.choices = char.choices or {}
    return char.choices
end

-- Returns "yes", "no", or nil (no choice made)
function ns.GetChoice(questID)
    local choices = GetChoices()
    local c = choices[questID]
    if c and c.expires and c.expires < time() then
        choices[questID] = nil -- quest has expired, forget the choice
        return nil
    end
    return c and c.choice
end

-- Set a choice. Clicking the same choice again clears it.
function ns.SetChoice(questID, choice)
    local choices = GetChoices()
    if choices[questID] and choices[questID].choice == choice then
        choices[questID] = nil
        return
    end
    local left = C_TaskQuest.GetQuestTimeLeftSeconds and C_TaskQuest.GetQuestTimeLeftSeconds(questID)
    choices[questID] = {
        choice  = choice,
        expires = time() + (left or 7 * 24 * 60 * 60), -- fall back to one week
    }
end
