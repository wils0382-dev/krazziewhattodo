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
      rewards = { 263466 }, -- Overflowing Abundant Satchel (several versions)
      note = "300+ Voidlight Marl (unverified)" },
    { name = "Legends of the Haranir", minIlvl = 240, gold = 2000,
      rewards = { 263467 }, -- Avid Learner's Supply Pack (several versions)
      note = "13 quests, 7 of them weekly" },
    { name = "Saltheril's Soiree", minIlvl = 260, gold = 2000,
      rewards = { 268489 }, -- Surplus Bag of Party Favors (3 versions at 90, one for 80-89)
      note = "~2,000g bag seen on an alt; rep only once a week per account" },
    { name = "Stormarion Assault", minIlvl = 280, gold = 2000,
      rewards = { 260940 }, -- Victorious Stormarion Pinnacle Cache
      note = "Veteran gear, transmog sets (unverified)" },
    { name = "Bountiful Delves", match = "bountiful delves", minIlvl = 285, gold = 0,
      note = "Gear and Delver's Journey; little gold" },
    { name = "Prey", minIlvl = nil, gold = 175,
      rewards = { 275726, 279574 }, -- Preyhunter's Champion Chest, Hero Chest (Veteran chest ID unknown)
      -- Item levels by difficulty (from Wowhead, via James)
      difficulties = {
          { name = "Normal",    drops = 266, track = "Adventurer", vault = 279 },
          { name = "Hard",      drops = 279, track = "Veteran",    vault = 292 },
          { name = "Nightmare", drops = 292, track = "Champion",   vault = 305 },
      },
      note = "Hard: ~175g. Prey vendors also sell rewards." },
    { name = "Trailing Xal'atath", minIlvl = nil, gold = nil,
      rewards = { 279527 }, -- Apex Cache
      note = "Lady Liadrin / Vereesa Windrunner; seems to be a random weekly; AI claimed up to 20,000g, unverified" },
    { name = "Aqir Invasion", minIlvl = nil, gold = nil,
      rewards = { 277283 }, -- Aqir Research Satchel
      note = "Map marker name not confirmed yet" },
}

-- The profile for an activity name (exact name, or the name starts with "match")
function ns.ProfileFor(name)
    local n = (name or ""):lower()
    for _, p in ipairs(ns.ACTIVITY_PROFILES) do
        local m = (p.match or p.name):lower()
        if n == m or n:find(m, 1, true) == 1 then return p end
    end
end
