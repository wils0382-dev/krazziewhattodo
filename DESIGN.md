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

## Suggested build order

1. ~~**Weekly caps**: stop chasing capped currencies.~~ Built in 1.1.0.
2. **Collectible rewards on world quests**: new categories (Mount, Pet, Toy, Appearance, Decor), auto-hidden once collected.
3. **Focus**: the goal-type priority list and presets.
4. **ATT detective step**: find out what ATT exposes and how to query it.
5. **Weeklies and events linked to goals**: using ATT where available, a hand-built list where not.
