-- Krazzie - What to do : PLAN ("Best for this character")
-- Ranks this week's activities for the character you're on:
--   1. drops anything done, skipped, or without a profile (ActivityData.lua)
--   2. puts anything below its minimum item level under "Not yet"
--   3. values the rest by your value priorities (gold first, etc.)
--   4. ranks them, WEIGHTED (each priority counts half as much as the one
--      above) or STRICT (first priority wins, the next only breaks ties)

local _, ns = ...
local Plan = {}
ns.Plan = Plan

local function Comma(n)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end

-- Equipped item level, rounded down
local function CharItemLevel()
    if GetAverageItemLevel then
        local _, equipped = GetAverageItemLevel()
        return math.floor(equipped or 0)
    end
    return 0
end

-- Gold value in copper, and where the figure came from
local function GoldFor(candidate)
    if candidate.goldOverride then return candidate.goldOverride, "on the map" end
    local p = candidate.profile
    local learned = ns.Activities:TypicalGold(p.name) or ns.Activities:TypicalGold(candidate.name)
    if learned then return learned, "learned" end
    if p.gold then return p.gold * 10000, "estimate" end
    return nil, nil
end

function Plan:Build(result, settings)
    local candidates, ilvl = {}, CharItemLevel()
    local acts = result.activities or {}

    -- This week's activities that have a profile
    for _, a in ipairs(acts.list or {}) do
        if not a.done and a.choice ~= "no" then
            local p = ns.ProfileFor(a.name)
            if p then table.insert(candidates, { name = a.name, profile = p, pinned = a.choice == "yes" }) end
        end
    end

    -- Delves, if you haven't reached your weekly goal
    local d = acts.delves
    if d and d.count < d.goal then
        local p = ns.ProfileFor("Bountiful Delves")
        if p then
            table.insert(candidates, { profile = p,
                name = ("Bountiful Delves (tier %d+, %d/%d)"):format(d.tier, d.count, d.goal) })
        end
    end

    -- Gold world quests currently on the map, as one entry
    local wqGold, wqCount = 0, 0
    for _, e in ipairs(result.entries or {}) do
        if e.isQuest and e.rank and not e.hidden then
            for _, r in ipairs(e.reasons or {}) do
                if r.category == "gold" then
                    wqGold, wqCount = wqGold + (e.gold or 0), wqCount + 1
                    break
                end
            end
        end
    end
    local wqProfile = ns.ProfileFor("Gold world quests")
    if wqCount > 0 and wqProfile then
        table.insert(candidates, { name = wqCount .. " gold world quests", profile = wqProfile, goldOverride = wqGold })
    end

    -- Too hard yet? Value the rest.
    local ranked, notYet = {}, {}
    for _, c in ipairs(candidates) do
        local minIlvl = c.profile.minIlvl
        if minIlvl and ilvl < minIlvl and not c.pinned then
            table.insert(notYet, c)
        else
            c.values, c.ilvl = {}, ilvl
            c.values.gold, c.goldSource = GoldFor(c)
            -- Transmog, mounts and other collectibles join here in stage 2
            table.insert(ranked, c)
        end
    end

    -- Rank
    local order = settings.valuePriority or { "gold" }
    if settings.rankingMode == "strict" then
        table.sort(ranked, function(a, b)
            if a.pinned ~= b.pinned then return a.pinned == true end
            for _, t in ipairs(order) do
                local va, vb = a.values[t] or 0, b.values[t] or 0
                if va ~= vb then return va > vb end
            end
            return a.name < b.name
        end)
    else
        -- Weighted: scale each value against the best on offer, then weight by priority
        local best = {}
        for _, c in ipairs(ranked) do
            for t, v in pairs(c.values) do best[t] = math.max(best[t] or 0, v or 0) end
        end
        local falloff = settings.weightFalloff or 0.5
        for _, c in ipairs(ranked) do
            local score, weight = 0, 1
            for _, t in ipairs(order) do
                if best[t] and best[t] > 0 then score = score + weight * (c.values[t] or 0) / best[t] end
                weight = weight * falloff
            end
            c.score = score
        end
        table.sort(ranked, function(a, b)
            if a.pinned ~= b.pinned then return a.pinned == true end
            if a.score ~= b.score then return a.score > b.score end
            return a.name < b.name
        end)
    end
    table.sort(notYet, function(a, b) return (a.profile.minIlvl or 0) < (b.profile.minIlvl or 0) end)

    return { ranked = ranked, notYet = notYet, ilvl = ilvl, mode = settings.rankingMode or "weighted", order = order }
end

-- "1. Abundance: Mining Voidburrow  ~4,250g (estimate)"
function Plan:Line(i, c)
    local text = ("%d. %s"):format(i, c.name)
    local gold = c.values and c.values.gold
    if gold and gold >= 10000 then
        text = text .. ("  |cffffd100~%sg|r |cff888888(%s)|r"):format(Comma(math.floor(gold / 10000)), c.goldSource)
    elseif gold then
        text = text .. "  |cff888888(little gold)|r"
    else
        text = text .. "  |cff888888(value unknown yet)|r"
    end
    -- Difficulty advice (e.g. Prey): the easiest difficulty whose drops beat your item level
    local diffs = c.profile.difficulties
    if diffs and c.ilvl then
        local advice
        for _, d in ipairs(diffs) do
            if d.drops > c.ilvl then
                advice = ("upgrades from %s (%d %s)"):format(d.name, d.drops, d.track or "")
                break
            end
        end
        text = text .. " |cff00ff00" .. (advice or "no gear upgrades (crests only)") .. "|r"
    end
    if c.pinned then text = text .. " |cff66ccffYour pick|r" end
    return text
end

function Plan:NotYetLine(c, ilvl)
    return ("|cff888888Not yet: %s (needs %d, you're %d)|r"):format(c.name, c.profile.minIlvl, ilvl)
end

-- "Item level 268 · weighted: gold > transmog"
function Plan:Summary(plan)
    return ("|cffaaaaaaItem level %d \194\183 %s: %s|r"):format(plan.ilvl, plan.mode,
        table.concat(plan.order, " > "))
end
