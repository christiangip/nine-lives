# 16 — Save System

**Milestone:** M1 · **Depends on:** 02 · **Blocks:** 13, 15
**Implements:** GDD §15.4–15.5, §16.3–16.4 · **Decisions:** **Q5 strict integrity**.

## Overview
Ten slots, autosave, and the **strict** roguelite integrity policy that protects
the stakes: missions are atomic, clean abort only while undetected, and quitting
while hot resolves as the Catch. Drives the Continue button and survives updates
via schema migration.

## Functional Requirements
- **FR-16-1** 10 independent slots under `user://saves/`; `scan_slots()` returns a 10-bool populated map; `populated_count()` drives Continue (15).
- **FR-16-2** Per-slot schema = permanent (Legacy/attributes/unlocks/stations/Stash/perks/stats) + current Streak (Notoriety/level/Edges/Heat/Take/job_board+seeds/checkpoint flag) + meta (summary fields + `schema_version`).
- **FR-16-3** `slot_summary()` reads meta cheaply **without** loading the full save.
- **FR-16-4** Autosave at the Hideout and after each completed mission (between-missions only).
- **FR-16-5** **Strict policy (Q5):** clean abort allowed only while undetected (keep secured loot, Streak intact); once `RunManager.committed` (alarm raised), quitting the app resolves as the Catch on next launch.
- **FR-16-6** Save/load round-trips all state exactly; delete frees a slot (with confirm in UI).
- **FR-16-7** Schema migration upgrades old saves across `schema_version` bumps.
- **FR-16-8** Saves are resilient to partial writes (atomic write-then-rename) and corruption (validate header; mark invalid slots).

## Phases
### Phase 16.1 — I/O & scan
- [ ] Serialize/deserialize the schema; atomic write; header validation.
- [ ] `scan_slots()` / `populated_count()` / `slot_summary()` (cheap meta read).

### Phase 16.2 — Autosave & strict policy
- [ ] Autosave hooks (Hideout + post-mission); block mid-mission saves.
- [ ] `committed` handling: hot-quit → Catch resolution on relaunch; clean pre-detection abort path.

### Phase 16.3 — Delete & migration
- [ ] Delete-slot; migration framework + at least one example migration + version stamping.

## Tests (GUT)
- (existing) `test_save_scan.gd` — 10 slots; Continue logic base case.
- `test_save_roundtrip.gd` — write a rich state → load → deep-equal.
- `test_strict_commit.gd` — simulating a hot-quit (`committed=true`) resolves as a Catch, not a free escape.
- `test_clean_abort.gd` — aborting while undetected keeps secured loot and the Streak.
- `test_migration.gd` — a v0 save loads and upgrades to the current schema.
- `test_atomic_write.gd` — an interrupted write leaves the previous save intact.

## Definition of Done
- [ ] FR-16-1..8 satisfied; phases checked; tests green.
- [ ] M1 manual: Continue restores a slot exactly; a hot-quit costs the run.
