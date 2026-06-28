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
- [ ] Define unlock-arc data; reveal/gating UI in the Hideout (13); milestone notifications.

### Phase 20.2 — Daily/weekly contracts
- [ ] Date→seed derivation; reproducible contract; local results tracking + a results screen.

### Phase 20.3 — Modifiers & seasons
- [ ] Rotating modifier scheduler; seasonal goal tracks + reward grants.

### Phase 20.4 — New-map delivery
- [ ] Validate that a new-archetype content pack (19) lands on the board live.

## Tests (GUT)
- `test_daily_seed.gd` — the same date yields the same contract across runs/machines.
- `test_milestone_gating.gd` — an unlock arc reveals content exactly at its Legacy/special-loot threshold.
- `test_modifier_rotation.gd` — the scheduler applies/removes the active global modifier on schedule.
- `test_new_archetype_pack.gd` — a packaged new archetype appears on the board with no code change.

## Definition of Done
- [ ] FR-20-1..6 satisfied; phases checked; tests green.
- [ ] A new map and a weekly modifier can be shipped purely as data/config.
