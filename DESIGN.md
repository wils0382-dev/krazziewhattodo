# Krazzie: Goals design notes

Ideas for the next big stage. Not built yet.

## The shift

Version 1 asks: **"Is this reward good?"**
(enough gold, a gear upgrade, a currency you've ticked)

The goals system asks: **"Does this get me closer to something I'm chasing, and do I still need it?"**

## 1. Goals

Things you're chasing, by type:

- Mounts
- Pets
- Toys
- Achievements
- Housing decor
- Appearances (transmog)
- Currencies
- Possibly more later

Weeklies, events (e.g. Saltheril's Soiree), Bountiful Delve rewards and similar are **only flagged when they lead to a goal you still need**. They may overlap with world quests; that's fine.

## 2. Goals retire themselves

Once a goal is collected, Krazzie stops chasing it, without you having to remember.

- The game can tell an addon whether you own a mount, pet or toy, or have an achievement.
- Some goals are account-wide (most collections), some are per character. Krazzie needs to know which.
- Collected goals can be kept in a "done" list, so nothing silently disappears.

## 3. Weekly caps

Some currencies have a weekly limit (e.g. Coffer Key Shards from world quests).

- The game reports how many you've earned this week and the weekly maximum.
- Once capped, Krazzie stops flagging that currency until the weekly reset, even if it's high on your priority list.
- **This is small and can be built on its own, before the rest.**

## 4. Focus (farming targets)

A second priority list, ranking goal *types*: e.g. mounts first, then decor, then toys.

- Switchable presets, e.g. "Mount farming", "Gold farming", "Gearing an alt".
- Change your farming target in one click, without re-sorting everything.
- Could be account-wide or per character, like the current settings.

## The catch: knowing what rewards what

- **World quests and quests in your log:** the game shows the reward, so Krazzie can detect "this rewards a mount you don't own" automatically.
- **Events, vendors, drops, delve chests:** the game often doesn't preview the reward. These need a list mapping each activity to its possible rewards.
- Building and maintaining that list is the biggest piece of work in this whole idea.

## Possible answer to the catch: All The Things (ATT)

ATT already knows sources (what drops from where, what vendors sell, event rewards) and what the account has collected.

- While the game runs, all loaded addons share memory, so Krazzie could **ask ATT questions in game** (e.g. "what Brewfest items am I missing, and where do they come from?").
- Example output: *Brewfest: 3 missing. Coren Direbrew (mount, daily kill); vendor toy (400 tokens).*
- Covers events, vendors, delve chests and drops, which the game itself doesn't preview.

Catches:

- **No official interface.** Krazzie would reach into ATT's internals, which can change in any ATT update. Build defensively: if ATT changes, goal features pause quietly; everything else keeps working.
- **Optional power-up.** Only works when ATT is installed and loaded. Krazzie must still work without it.
- **Heavy.** Query sparingly (login, on demand) and cache results to avoid stutters.
- **Read, don't copy.** Asking ATT in game is fine; copying its database into Krazzie is not (licence).

First step: a debug command to discover what ATT exposes in its current version, and how to query it (e.g. for Brewfest), the same way we found Special Assignments.

## Idea: look wider for event vendors (filed for later)

**Found during Brewfest:** the Brewfest vendor sold two decor items for gold that Krazzie never listed. Krazzie only reads what ATT files *under* the Brewfest header, so anything ATT files elsewhere (e.g. its Housing section) or doesn't know about is invisible.

- **Fix at the source:** report missing vendor items to the ATT team (active on Discord).
- **Fix in Krazzie:** when an event activity is a vendor NPC, also ask ATT for every other place that NPC appears (`SearchForField("npcID", id)`) and include missing items from those too, deduplicated.
- **Testing:** needs a live example. The two Brewfest decor items were bought, so they're collected now. Try with Hallow's End or another holiday's vendors.

## Next major feature: weekly activities (filed for later)

Source: an AI-generated summary James gathered. **Treat its numbers and details as unverified**: Krazzie reads real rewards from the game, so this list is only a checklist of what to look for.

### Already covered (1.6.0 repeatable quests)

- **Dungeon weeklies** (e.g. [Dungeon] Murder Row, Windrunner Spire) appear as repeatable map quests.
- **Housing / Neighborhood: Going Postal** appears with Voidlight Marl and Community Coupons.
- **Prey hunts** (e.g. "Prey: Anguish from Beyond") appear with Coffer Key Shards.

### Needs new detection

| Activity | Where | How Krazzie could detect it |
|---|---|---|
| Pinnacle weekly (Unity Against the Void, from Lady Liadrin, Silvermoon) | Quest | In log: already in "This week". Missing: a reminder to pick it up. Needs its quest ID(s); check completion with `IsQuestFlaggedCompleted`. |
| A Call to Delves (5 Midnight delves) | Quest | Same as above. |
| Bountiful Delves | Map | Delve markers (area POIs); bountiful ones likely have their own icon name. Detective step needed. |
| Saltheril's Soiree (Eversong) | Map event | Already seen in debug under "Map events" (POI 8600, widget text). Completion via its weekly quest(s). |
| Abundance (all zones) | Map event | Detective step needed. |
| Legends of the Haranir (Harandar, warband-wide) | Scenario | Detective step needed; account-wide completion. |
| Stormarion Assault / Defending the Singularity (Voidstorm) | Map event | Related repeatables already seen (Stormarion Core rewards). Detective step needed. |
| Profession weeklies | Quests | Filter by the character's professions (`GetProfessions`). |
| Prey weekly (Garden Variety Sacrifices, Renown 4) | Quest | Unlock-dependent; check availability/completion by quest ID. |

### Detective results (1.6.2) and first build (1.7.0)

- **Bountiful Delves:** `GetDelvesForMap`, atlas `delves-bountiful`. Tooltip has Restored Coffer Keys held, shards, story variant, time left.
- **Events:** `GetEventsForMap`. Soiree, Abyss Anglers, Legends of the Haranir, Stormarion Assault, Abundance (rotates; bountiful variant gives a Restored Coffer Key), Prey, Void Incursion (region progress bar).
- **Ritual Sites:** area markers, atlas `Ritual-Sites-Map-Icon`, award Field Accolades.
- **Not found:** Liadrin's Pinnacle weekly and A Call to Delves.
- **1.7.0** lists all of the above in a "This week's activities" section with tick/cross (cross = skip until weekly reset). Completion isn't detected yet: needs each event's weekly quest ID.

### The core design: three modes per activity, per character

- **Always**: chase it on this character regardless (e.g. the Pinnacle weekly on every toon).
- **If worth it**: only flag it when its rewards match this character's priorities, like world quests.
- **Off**: never show it on this character.

Fits the existing account/character settings layers. Would live on its own tab in the settings redesign.

### Approach

1. Detective pass during the week: map events and area POIs per zone (the existing `/kwtd debug` already records these), plus quest IDs for the named weeklies.
2. Build a small, hand-checked list of weekly activities (name, quest IDs, zone, account-wide or not).
3. "Weekly activities" section in the window, using the three modes.

## Idea: settings redesign (filed for later)

The settings panel keeps getting longer. Plan:

- **Tabs** instead of one long page, e.g. **Rules** (thresholds, empty slots, caps), **Rewards** (priority list, currencies, rep), **Events** (event goals, item types) and **Window** (sections, login, Esc, focus, minimap).
- **Per-event switches:** a list of every event Krazzie has seen (Timewalking, Darkmoon Faire, Brewfest...), each with its own tick box. Combined with "Separate settings for this character", an alt can switch off Timewalking entirely while the main keeps it.

## Suggested build order

1. ~~**Weekly caps**: stop chasing capped currencies.~~ Built in 1.1.0.
2. **Collectible rewards on world quests**: new categories (Mount, Pet, Toy, Appearance, Decor), auto-hidden once collected.
3. **Focus**: the goal-type priority list and presets.
4. ~~**ATT detective step**~~ Done: ATT exposes `ATTC`, with Holidays (-36) and World Event (-734) sections, collected flags and source chains. `/kwtd event <name>` built in 1.2.0.
5. **Weeklies and events linked to goals**: holidays done in 1.3.0 (via ATT). Vendor token costs done in 1.5.0. Still to do: non-holiday weeklies, the focus/preset system.
