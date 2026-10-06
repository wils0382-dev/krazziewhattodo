# Krazzie - What to do

A World of Warcraft: Midnight addon that tells each character which world quests are worth doing, based on rules you set. It runs alongside the Midnight Routine addon.

## What it does

- Scans every Midnight zone's world quests on login.
- Flags quests that pay gold above your minimum, or give gear that beats what you're wearing.
- Finds Special Assignments: locked ones (with how many world quests are left to unlock) and unlocked ones.
- Flags every world quest in a zone with a locked Special Assignment, since any of them helps unlock it.
- Lists everything grouped by zone and sorted by your priority order.
- Tick a quest to always show it, cross it to hide it. Choices are per character and clear when the quest expires.
- Settings can be account-wide, or separate per character.

## Commands

| Command | What it does |
|---|---|
| `/kwtd` | Open or close the window |
| `/kwtd chat` | Print the worth-doing list to chat |
| `/kwtd chat all` | Print everything to chat, skipped quests greyed out |
| `/kwtd caps` | Every known currency with its weekly and total limits |
| `/kwtd att` | Record what All The Things exposes to other addons (to the save file) |
| `/kwtd att2` | Record ATT's database layout and test searches (to the save file) |
| `/kwtd event <name>` | What you're still missing from an event, e.g. `/kwtd event brewfest` (needs All The Things) |
| `/kwtd debug` | Record hidden quest and map-marker labels for the current zone to the save file |

## Files

| File | Job |
|---|---|
| `KrazzieWhatToDo.toc` | Addon ID card: name, version, load order |
| `Settings.lua` | Default rules, colours, zone IDs and other game data |
| `Profile.lua` | Works out which settings apply (defaults, account, character) |
| `Choices.lua` | Remembers ticks and crosses per character |
| `Scanner.lua` | Finds quests and Special Assignments, applies the rules, sorts the list |
| `Debug.lua` | The `/kwtd debug` detective tool |
| `Window.lua` | The main window |
| `SettingsPanel.lua` | The settings panel beside the window |
| `Alts.lua` | Per-character snapshots and the Alts panel |
| `Events.lua` | Event goals, read from All The Things |
| `Broker.lua` | Titan Panel and minimap icon |
| `Core.lua` | Start-up, auto-refresh and slash commands |

Saved data lives in `WTF\Account\<account>\SavedVariables\KrazzieWhatToDo.lua`.

## Things we discovered about the game

- Special Assignments are **not** world quests while locked. They're map markers (area POIs) whose icon name contains `Capstone`, ending in `Locked`.
- A locked Special Assignment's tooltip counts down ("Complete 1 world quest in Eversong to unlock").
- Once unlocked, the marker disappears and it becomes a world quest with tag ID `286` ("Capstone World Quest").
- Some quest-reward "currencies" are really reputation; `C_CurrencyInfo.GetFactionGrantedByCurrency` tells them apart.
- All The Things (5.3.x): main table `ATTC`. Holidays are under headerID -36, World Events under -734. Objects have `collectible`, `collected`, `u` (unobtainable) and a `parent` chain showing the source (e.g. Brewfest > Coren Direbrew > loot bag > daily quest > mount).
- The in-game calendar's holiday IDs differ from ATT's (Brewfest: calendar 372, ATT 7), but the names match, so events are linked by name.
- Silvermoon City world quests count towards Eversong Woods' unlock.
- Zone map IDs: Eversong Woods 2395, Zul'Aman 2437, Harandar 2413, Voidstorm 2405, Silvermoon City 2393, The Coiled Isle 2512, Vaults of Atal'Utek 2509.

## Roadmap

See [DESIGN.md](DESIGN.md) for the goals system (collectibles, weekly caps, farming focus).

- [x] Window comfort: stays open with the map, resizing, collapsible zones (focus on current zone)
- [x] Titan Panel / minimap icon (LibDataBroker, borrowed from Routine/Titan)
- [x] Quests tick themselves off when handed in
- [x] Currency rewards as priority categories (learned automatically)
- [ ] Minimum amounts per currency
- [x] Turn categories on/off (per character via separate settings)
- [x] "Any gear" category (for disenchanting), separate from upgrades
- [x] Alt hand-off: suggest which character to log onto next
- [x] Weekly quests from the quest log, with ready-to-hand-in alerts
- [ ] World bosses
- [ ] Profession dailies/weeklies based on the character's professions
- [ ] Off-hand comparison for dual-wielders
- [ ] Map events (e.g. Saltheril's Soiree, Void incursions)
- [ ] Weekly activities (e.g. Saltheril's Soiree, Bountiful Delve gilded rewards, other weeklies)

## Version history

- **1.3.0** Running holidays appear in the window, one line per activity, using All The Things; per-type switches; duplicate and name fixes
- **1.2.0** `/kwtd event <name>`: missing collectibles from an event via All The Things
- **1.1.1** `/kwtd att2` deeper ATT detective
- **1.1.0** Capped currencies stop counting; `/kwtd caps` and `/kwtd att` detective commands
- **1.0.0** World quest planner complete: rules, Special Assignments, priorities, per-character choices and settings, weeklies, alts, Titan Panel
- **0.15.0** "This week" section for weekly quests in your log; Alts panel with next-up suggestion; alts in the Titan tooltip
- **0.14.2** Off-hand rewards no longer count as upgrades for characters wielding a two-hander
- **0.14.1** Scans retry while reward data is still loading; refresh after loading screens
- **0.14.0** Reputation rewards split from currencies into their own category (off by default)
- **0.13.0** Categories can be switched off; any-gear category; currencies learned from rewards as categories
- **0.12.0** Titan Panel and minimap icon with a to-do count
- **0.11.0** Auto-refresh on quest hand-in and when map markers change; completed quests filtered out
- **0.10.0** Window stays open with the map; resizable; collapsible zones; focus on current zone
- **0.9.0** In-game settings panel; account and per-character settings
- **0.8.0** Tick/cross per quest, per character, expiring with the quest
- **0.7.0** Split into separate files; main window
- **0.6.0** Unlocked Special Assignments (tag 286); unlock countdown; Silvermoon linked to Eversong
- **0.5.0** Special Assignments via map markers; priority order
- **0.4.0** Quests filed under their own zone; map marker debugging
- **0.3.0** Debug command; save file
- **0.2.0** Gold and gear-upgrade rules
- **0.1.0** First scanner, chat output
