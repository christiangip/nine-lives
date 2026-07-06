# Live Ops — milestones, challenges, rotating events & seasons

How the "living game" surface (task 20) is authored. Everything here is **data/config, not
code** — built on the expansion framework (task 19) and the frozen EventBus. If you're adding a
new *location/map*, see also [PREFAB_AUTHORING.md](PREFAB_AUTHORING.md) and
[CONTENT_PACKS.md](CONTENT_PACKS.md); for the currencies these payouts feed, see the economy
table `game/data/economy.json`.

## The pieces at a glance

| Feature | Authored in | Read by |
|---|---|---|
| Milestone unlock arcs | `MilestoneDef` `.tres` in `game/resources/milestones/` (or a pack's `milestones/`) | `ProgressionManager.check_milestones()` |
| Daily/weekly Challenges | derived from the date; settings in `game/data/liveops.json` | `LiveOps` + `GameManager.enter_challenge` |
| Rotating global modifier | `modifier_rotation` in `liveops.json` | `LiveOps.active_modifiers` → `RunManager.refresh_board` |
| Seasonal goals | `seasons` in `liveops.json` | `LiveOps.active_season` + `ProgressionManager` season seams |
| New maps/archetypes | `ArchetypeDef` `.tres` in a content pack | `MissionBoard.generatable_archetypes` |

Surfaced in the Hideout by the **"The Wire"** station (`live_board`, manifest-driven) and demoed
in `game/scenes/live/LiveSandbox.tscn` (Gallery Hub → *Live Sandbox*).

## Milestone unlock arcs (FR-20-1)

A milestone auto-**grants content for free** the moment a lifetime threshold is met, and announces
itself at the next Hideout visit. Add one by dropping a `MilestoneDef` `.tres`:

```
id                    = &"master_vault"          # lowercase_snake, unique
display_name          = "Master Thief"
description           = "…shown on The Wire…"
threshold_legacy      = 5000                       # lifetime Legacy *earned* (stats["legacy_earned"]); 0 = no Legacy gate
require_special_loot   = &""                        # a LootDef special_hook that must be delivered too; &"" = none
grant_stations        = [&"fence"]                 # StationDef ids unlocked for free
grant_gear            = [&"casing_visor"]          # GearDef ids unlocked for free
grant_archetypes      = [&"federal_reserve"]       # ArchetypeDef ids that then appear on the board
reward_legacy         = 0                           # one-off Legacy bonus on reach
order                 = 4                           # UI ordering on The Wire
```

- Gates on **lifetime Legacy earned** (monotonic) so *spending* Legacy never un-reveals a milestone.
- Grants are idempotent (`milestones_reached`), permanent, and survive save/load.
- To gate a **map** behind a milestone, set `ArchetypeDef.unlock_milestone = &"<milestone id>"`; it stays
  off the board until `grant_archetypes` reveals it. Empty (`&""`) = always available.
- `ContentValidator` checks every grant id resolves; run `tools/scripts/validate_content.sh`.

## The live manifest — `game/data/liveops.json` (FR-20-6)

A single JSON file read **directly** by `LiveOps` (like `economy.json`), so it hot-edits and is
directly swappable for a fetched remote manifest later. No networking today.

```jsonc
{
  "daily_legacy_reward": 200,          // one-time first-clear bonus
  "weekly_legacy_reward": 600,
  "challenge_tier": 3,                  // difficulty tier for Challenge contracts
  "daily_archetypes": [],              // allow-list of eligible maps ([] = any ungated generatable)
  "weekly_archetypes": [],

  "modifier_rotation": {               // FR-20-3
    "epoch_unix": 1704067200,          // reference date the ring counts from
    "period_days": 7,                  // each slot is active this many days
    "slots": ["", "extra_patrols", "", "blackout"]  // "" = a calm week; ids must be real ModifierDefs
  },

  "seasons": [                          // FR-20-4
    {
      "id": "founding_season",
      "title": "Founding Season",
      "start_unix": 1704067200,
      "duration_days": 3650,           // [start, start+duration) window
      "goals": [
        { "id": "big_take", "kind": "loot_value", "target": 50000,
          "reward_legacy": 800, "reward_title": "title_big_earner", "display": "Secure $50,000 in loot value" }
      ]
    }
  ]
}
```

- **Daily/weekly seed:** `LiveOps.daily_seed(now)` / `weekly_seed(now)` derive a machine-independent
  seed from the UTC day/week via a self-rolled FNV-1a hash — **the same job for everyone** on a date.
  `LiveOps.challenge_contract(seed, candidates, kind)` turns it into a reproducible `Contract`.
- **Rotating modifier:** `active_modifiers(cfg, now)` picks the ring slot for *now*; `RunManager.refresh_board`
  appends it to every board contract, so it flows through `MissionPopulator` with no populator change.
- **Season goal `kind`:** `contracts_completed` · `loot_value` · `special_loot` · `legacy_earned`
  (all already tracked in `ProgressionManager.stats`). Progress is measured from a **baseline**
  snapshotted when the player first views the season, so a mid-account season is fair.
- Rewards are **Legacy + a dormant `reward_title`** id (recorded in `titles_earned`, rendered by a
  future cosmetics pass).

## Daily/weekly Challenges are standalone (FR-20-2)

A Challenge runs **outside** the endless Streak: `RunManager.begin_challenge` snapshots the Streak,
the mission plays on a clean scratch run, and `end_challenge` restores it verbatim — a Catch in a
Challenge never converts your Streak, and an alarm never flips the on-disk commit flag. Local
best-time/score per date-seed lives in `user://challenge_results.json` (outside save slots,
leaderboard-ready). Regression-locked by `test_challenge_isolation.gd`.

## Shipping a new map/event as a pack (FR-20-5)

Drop a folder in `game/packs/<id>/` (see `game/packs/live_season/` — "Casino Nights"):
`archetypes/*.tres` (a new map), `milestones/*.tres`, `modifiers/*.tres`. Enable it
(`PackManager.set_enabled` / the sandbox `[P]`) and it lands on the board live — no client rebuild.
Reference the new modifier id from a `liveops.json` rotation slot to feature it as the week's event.
