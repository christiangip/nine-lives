# 16 — Save System

**Milestone:** M1 · **Depends on:** 02 · **Blocks:** 13, 15
**Implements:** GDD §15.4–15.5, §16.3–16.4 · **Decisions:** **Q5 strict integrity**.

> **↩ From 09 (Loadout/Gear):** the Streak's equipped loadout is already round-trippable —
> `RunManager.loadout().to_dict()` / `from_dict()` (tested in `test_loadout_gear.gd`). Fold that dict
> into the **Streak** section of the save schema (§16 "current Streak") so the equipped set + consumable
> counts survive save/load, then come back and tick the 09 DoD's second bullet ("round-trips through
> save") in `09_…md`.

> **↩ From 15 (UI/HUD/Menus):** the Main Menu + 10-slot **SlotPopup** UI is fully built and already calls
> the SaveManager seams — `scan_slots()` / `slot_summary(slot)` / `save_slot(slot)` / `load_slot(slot)` /
> `delete_slot(slot)` (+ `autosave()` at the hub / post-mission). They're stubs today, so Continue is
> correctly greyed and every slot reads "Empty" on a fresh profile. Fill these in here and the menu lights
> up with **no UI edit**. The five summary fields SlotPopup renders are `{streak_len, legacy, playtime,
> last_played, last_contract}` (see `SlotPopup.format_slot`); `GameManager.start_new_game/continue_game`
> already route through the popup. Then **add the two save-backed integration tests** task 15 deferred —
> Continue enables once a real temp save exists, and a real occupied slot renders the five fields — and
> tick FR-15-2/3 + the M1 gate in `15_…md`. Also swap `GameManager.continue_game`'s `TODO[16]` for the
> real `load_slot` rehydrate.

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
- [x] Serialize/deserialize the schema; atomic write; header validation.
- [x] `scan_slots()` / `populated_count()` / `slot_summary()` (cheap meta read).

### Phase 16.2 — Autosave & strict policy
- [x] Autosave hooks (Hideout entry + post-mission + each station spend); mid-mission saves blocked (autosave only runs between missions via `goto_hideout`/panel-close).
- [x] `committed` handling: hot-quit → Catch resolution on relaunch (on-disk `active_mission_committed` checkpoint flip on alarm); clean pre-detection abort keeps Streak + secured loot.

### Phase 16.3 — Delete & migration
- [x] Delete-slot; migration framework (`migrate()` stepwise loop) + the `_migrate_1_to_2` example + version stamping (`SCHEMA_VERSION = 2`).

## Tests (GUT)
- (existing) `test_save_scan.gd` — 10 slots; Continue logic base case.
- [x] `test_save_roundtrip.gd` — write a rich state → load → deep-equal (permanent + Streak, incl. loadout/job_board/intel).
- [x] `test_strict_commit.gd` — a hot-quit (`active_mission_committed=true`) resolves as a Catch, not a free escape (+ no double-Catch on the next load).
- [x] `test_clean_abort.gd` — a save taken while undetected keeps secured Take/Notoriety and the Streak.
- [x] `test_migration.gd` — a v1 save loads and upgrades to the current schema (dict + on-disk file).
- [x] `test_atomic_write.gd` — an interrupted write / corrupt file leaves the previous save intact and reads as empty.
- [x] `test_save_menu_integration.gd` — (task-15 deferral) Continue enables once a real save exists; an occupied slot renders the five fields.
- [x] `test_save_scenes.gd` — the `SaveSandbox.tscn` demo instantiates headlessly.

## Definition of Done
- [x] FR-16-1..8 satisfied; phases checked; tests green (headless GUT **343/343** on Godot 4.6.3).
- [x] M1 manual: Continue restores a slot exactly; a hot-quit costs the run. *(F6 sign-off passed 2026-07-05 via `SaveSandbox.tscn` + the real MainMenu→SlotPopup→Hideout loop.)*

## Progress note
**Code + automated DoD complete & verified green** on Godot 4.6.3 (headless GUT **343/343**, +12
task-16 tests). `SaveManager` writes one JSON file per slot under `user://saves/` with **atomic
write-then-rename** (`_write_atomic`: fill `.tmp` → swap), header validation, and a `JSON`-instance
parse so corrupt slots read as empty without logging. The schema is composed from new
`to_dict()/from_dict()` seams on **ProgressionManager** (permanent block + a new `playtime_seconds`)
and **RunManager** (Streak block, folding in the existing `Loadout`/`Contract` serializers +
`intel_by_seed`). **Strict integrity (Q5):** a top-level `active_mission_committed` checkpoint flag —
distinct from the normal `streak.committed` — is flipped on-disk the instant an alarm trips
(`RunManager._on_alarm_tripped` → `mark_committed()`); `load_slot` resolving that flag runs
`end_streak("caught_hot_quit")` (the hot-quit Catch) and re-persists the cleared Streak. **Autosave**
(`goto_hideout` arrival, `start_new_game` fresh slot, each Hideout station spend) only ever fires
between missions. **Migration** bumped `SCHEMA_VERSION → 2` with `_migrate_1_to_2` defaulting the two
v2-new fields. The Main Menu / `SlotPopup` needed **no edits** — they light up on the now-real seams
(closes the `↩ From 15` deferral + its two integration tests, and the `↩ From 09` loadout↔save DoD
bullet). Demo: `game/scenes/menu/SaveSandbox.tscn` (+ `SaveSandboxDebug.gd`) — a live 10-slot readout
with dev keys for save/load/delete, a hot-quit→Catch simulation, and a v1→v2 migration round-trip,
opening the real MainMenu/SlotPopup. **F6 "feel" playtest signed off 2026-07-05 → Task 16 complete
(`[x]`).** With 16 landed, the **M1 milestone gate** is met (all spanned tasks + the manual checklist).
