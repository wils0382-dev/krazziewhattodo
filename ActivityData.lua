-- Krazzie - What to do : ACTIVITY DATA
-- What Krazzie knows about each activity, for ranking "Best for this character".
-- STARTING GUESSES: mostly from an AI-generated table, so unverified. Change
-- any number you know better. Gold figures are replaced by what Krazzie learns
-- from your own completions, once it has some.
--
--   name    = the name used when ranking (and for learned rewards)
--   match   = how the activity's name starts in the window (any capitals)
--   minIlvl = item level needed to do it comfortably (below this: "Not yet")
--   gold    = rough gold it pays, as a starting estimate (nil = unknown)
--   note    = anything worth remembering

local _, ns = ...

ns.ACTIVITY_PROFILES = {
    { name = "Gold world quests", match = "gold world quests", minIlvl = 260,
      note = "Gold is added up from the gold world quests on the map right now" },
    { name = "Abundance", match = "abundance", minIlvl = 240, gold = 4250,
      note = "Adventurer loot bag, 300+ Voidlight Marl (unverified)" },
    { name = "Legends of the Haranir", minIlvl = 240, gold = 2000,
      note = "Veteran/Explorer gear, Avid Learner's Supply Pack (unverified)" },
    { name = "Saltheril's Soiree", minIlvl = 260, gold = 2000,
      note = "~2,000g bag seen on an alt; rep only once a week per account" },
    { name = "Stormarion Assault", minIlvl = 280, gold = 2000,
      note = "Veteran gear, transmog sets (unverified)" },
    { name = "Bountiful Delves", match = "bountiful delves", minIlvl = 285, gold = 0,
      note = "Gear and Delver's Journey; little gold" },
    { name = "Prey", minIlvl = nil, gold = 175,
      note = "Hard: ~175g plus Veteran gear (279 seen)" },
    { name = "Trailing Xal'atath", minIlvl = nil, gold = nil,
      note = "Lady Liadrin's weekly; AI table claimed up to 20,000g, unverified" },
}

-- The profile for an activity name (exact name, or the name starts with "match")
function ns.ProfileFor(name)
    local n = (name or ""):lower()
    for _, p in ipairs(ns.ACTIVITY_PROFILES) do
        local m = (p.match or p.name):lower()
        if n == m or n:find(m, 1, true) == 1 then return p end
    end
end
