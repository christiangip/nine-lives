# 20 — Progression Milestones & Live Content

**Milestone:** M4 · **Depends on:** 12, 13, 19 · **Blocks:** —
**Implements:** GDD §18 · **Decisions:** built on the expansion framework (19).

## Overview
Turn the data platform into a living game: long-arc **milestone unlocks** (the
safehouse and arsenal growing over many runs) and **live/seasonal** features
(daily/weekly seeded contracts, rotating global modifiers, seasonal goals). This is
the "progression milestone adds / new maps" expansion surface the project targets.

## Functional Requirements
- **FR-20-1** Milestone unlock arcs: stations/gear/archetypes gated behind Legacy thresholds and/or delivered special loot, revealed as the player progresses (data-driven via 19).
- **FR-20-2** **Daily/weekly seeded contracts**: a date-derived seed produces an identical contract for everyone; optional local best-time/score tracking (leaderboard-ready).
- **FR-20-3** **Rotating global modifiers** ("blackout week," "extra patrols") applied to the board for a period.
- **FR-20-4** **Seasonal goals**: time-boxed objective tracks awarding cosmetic/Legacy rewards.
- **FR-20-5** New **maps/archetypes** ship as content packs (19) and appear on the board without a client rebuild.
- **FR-20-6** All live config is data/remote-tolerant (a config file or fetched manifest) so events rotate without code.

## Phases
### Phase 20.1 — Milestone arcs
- [x] Define unlock-arc data; reveal/gating UI in the Hideout (13); milestone notifications.
  *`MilestoneDef` (22nd `Content` registry `Content.milestones`, pack-extensible) + 5 base arcs;
  `ProgressionManager.check_milestones()` auto-grants stations/gear/archetypes for free at a lifetime-
  Legacy / special-loot threshold, emits the local `milestone_unlocked` signal; the Hideout drains a
  toast + the "The Wire" station shows arc progress. Gated maps via `ArchetypeDef.unlock_milestone`.*

### Phase 20.2 — Daily/weekly contracts
- [x] Date→seed derivation; reproducible contract; local results tracking + a results screen.
  *`LiveOps.daily_seed/weekly_seed` (self-rolled stable FNV-1a — cross-machine identical) →
  `challenge_contract`; **standalone** Challenge runs isolated from the Streak (`RunManager.begin/
  end_challenge` snapshot/restore + suppressed `mark_committed`); best time/score in
  `user://challenge_results.json` (`LiveChallenges`); `MissionResults` gained challenge lines.*

### Phase 20.3 — Modifiers & seasons
- [x] Rotating modifier scheduler; seasonal goal tracks + reward grants.
  *`LiveOps.active_modifiers` (ring by day-bucket) → `RunManager.refresh_board` appends board-wide;
  `LiveOps.active_season` + `ProgressionManager` season seams (baseline-relative progress, claim →
  Legacy + dormant title). All config in `game/data/liveops.json`.*

### Phase 20.4 — New-map delivery
- [x] Validate that a new-archetype content pack (19) lands on the board live.
  *`game/packs/live_season/` ("Casino Nights") ships a new archetype + milestone + modifier as data,
  disabled by default; `test_new_archetype_pack.gd` proves it reaches `generatable_archetypes()` on
  enable with no code change.*

## Tests (GUT) — all green (Godot 4.6.3, 407/407)
- [x] `test_daily_seed.gd` — the same date yields the same contract across runs/machines (stable-hash spec anchor).
- [x] `test_milestone_gating.gd` — an unlock arc reveals + auto-grants content exactly at its Legacy/special-loot threshold.
- [x] `test_modifier_rotation.gd` — the scheduler applies/removes the active global modifier on schedule.
- [x] `test_new_archetype_pack.gd` — a packaged new archetype appears on the board with no code change.
- [x] `test_challenge_isolation.gd` — a Challenge never mutates the Streak or the on-disk commit flag.
- [x] `test_live_scenes.gd` — the Live Board panel + Live Sandbox instantiate cleanly (headless smoke).

## Definition of Done
- [x] FR-20-1..6 satisfied; phases checked; tests green.
- [x] A new map and a weekly modifier can be shipped purely as data/config.
  *Proven by the `live_season` pack (map + modifier as data) and the `liveops.json` rotation manifest.*

## Notes
- **Decisions (user):** Daily/weekly = standalone Challenge mode; milestones auto-unlock for free;
  seasonal rewards = Legacy + a dormant title id; live config = a local JSON manifest (no networking).
- EventBus stayed **frozen** (milestone notify via a local `ProgressionManager` signal); stayed at
  **10 autoloads** (`LiveOps`/`LiveChallenges` are pure-static, like `PackManager`). Persistence is
  additive-with-defaults (no `SCHEMA_VERSION` bump). `validate_content.sh` green.
- **Residual `[~]`:** in-editor F6 "feel" sign-off on `game/scenes/live/LiveSandbox.tscn` (mark `[x]`
  after a human pass, mirroring prior greyboxes).
