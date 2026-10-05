-- Krazzie - What to do : SETTINGS
-- The DEFAULTS below are the starting values. Anything you change in the
-- in-game Settings panel is saved separately and overrides these.
-- Colours and game data further down are still changed here.

local _, ns = ... -- "ns" is a shared box every Krazzie file can read and write

------------------------------------------------------------
-- DEFAULT RULES (change these in game via the Settings button)
------------------------------------------------------------
ns.DEFAULTS = {
    minGold    = 250, -- flag gold quests paying at least this much (in gold)
    minUpgrade = 1,   -- flag gear at least this many item levels above what you wear

    -- Priority order inside each zone, top = most important
    priority = {
        "pick",   -- quests you ticked yourself
        "gear",   -- gear upgrades
        "gold",   -- gold above minGold
        "sa",     -- the Special Assignment itself
        "unlock", -- world quests that count towards unlocking a Special Assignment
    },

    openOnLogin = true,  -- open the window automatically when you log in
    chatOnLogin = false, -- also print the list to chat on login

    closeOnEscape    = false, -- Esc (and opening the map) closes the window
    focusCurrentZone = false, -- expand only the zone you're in, collapse the rest
    showMinimap      = true,  -- show the minimap button
}

------------------------------------------------------------
-- LOOK: colours are { red, green, blue, opacity }, each 0 to 1
------------------------------------------------------------
ns.THEME = {
    background = { 0.05, 0.05, 0.08, 0.92 }, -- near-black panel
    border     = { 1.00, 0.60, 0.00, 0.80 }, -- Krazzie orange
}

------------------------------------------------------------
-- GAME DATA (rarely needs changing)
------------------------------------------------------------
-- Midnight zone map IDs to scan
ns.ZONES = {
    2395, -- Eversong Woods
    2437, -- Zul'Aman
    2413, -- Harandar
    2405, -- Voidstorm
    2393, -- Silvermoon City
    2512, -- The Coiled Isle
    2509, -- Vaults of Atal'Utek (sub-level)
}

-- Some maps count as part of a bigger zone for Special Assignment unlocks
ns.COUNTS_AS = {
    [2393] = 2395, -- Silvermoon City counts as Eversong Woods (confirmed)
    [2509] = 2512, -- Vaults of Atal'Utek counts as The Coiled Isle (assumed)
}

-- Quest tag the game gives an UNLOCKED Special Assignment ("Capstone World Quest")
ns.SA_TAG_ID = 286

-- Which character slot(s) each kind of gear goes into.
-- Rings and trinkets have two slots; we compare against the weaker one.
ns.SLOTS = {
    INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3},
    INVTYPE_CHEST = {5}, INVTYPE_ROBE = {5}, INVTYPE_WAIST = {6},
    INVTYPE_LEGS = {7}, INVTYPE_FEET = {8}, INVTYPE_WRIST = {9},
    INVTYPE_HAND = {10}, INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14},
    INVTYPE_CLOAK = {15},
    INVTYPE_WEAPON = {16}, INVTYPE_2HWEAPON = {16}, INVTYPE_WEAPONMAINHAND = {16},
    INVTYPE_RANGED = {16}, INVTYPE_RANGEDRIGHT = {16},
    INVTYPE_WEAPONOFFHAND = {17}, INVTYPE_SHIELD = {17}, INVTYPE_HOLDABLE = {17},
}

-- Chat message with our coloured prefix
function ns.Say(msg)
    print("|cffff9900Krazzie:|r " .. msg)
end
