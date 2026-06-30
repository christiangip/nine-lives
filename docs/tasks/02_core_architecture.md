# 02 — Core Architecture & Data Framework

**Milestone:** M0 · **Depends on:** 01 · **Blocks:** 03, 11, 12, 13, 16
**Implements:** GDD §16.1–16.2 · **Decisions:** data-driven everything.

## Overview
The decoupling and expandability backbone: the EventBus contract, the
GameManager state machine, and the **content registries** that let new `.tres`/JSON
content appear without code edits. Get this right and every later list is additive.

> **Status (2026-06-29):** Implemented and **verified green on Godot 4.6.3** (headless GUT —
> 22/22 tests, the 4 new ones for this list among them). Content registries live in a new
> **10th autoload `Content`** (one generic `ContentRegistry` per def type, in
> `game/systems/core/`), paired with a `Services` static locator and a `SaveManager.migrate()`
> schema hook. Notes: (1) the `data/*.json` archetype sample hydrates scalar fields only —
> id-reference arrays such as `loot_table` are resolved by `MissionGenerator` in `11`;
> (2) the first real engine run surfaced a latent `01` bug — `SettingsManager.load()` shadowed
> Godot's global `load()`; renamed to `load_config()`.

## Functional Requirements
- **FR-02-1** `EventBus` exposes the documented signal set; it contains **no logic**.
- **FR-02-2** `GameManager` implements `BOOT→MAIN_MENU→HIDEOUT→MISSION→MISSION_RESULTS` and is the **only** place scene swaps happen.
- **FR-02-3** A generic `ContentRegistry` scans a folder of a given `*Def` type and indexes instances by `id`; lookups are by id, never by hard-coded branch.
- **FR-02-4** Registries exist for every def type (loot, gear, edges, perks, archetypes, objectives, modifiers, enemies, attributes, stations, intel).
- **FR-02-5** Adding a new `.tres`/JSON instance makes it queryable with **zero code changes** (proven by test).
- **FR-02-6** Base components (`Interactable`, `DetectionSensor`, `Minigame`) compile and are attachable.

## Phases
### Phase 02.1 — EventBus & state machine
- [x] Freeze the signal catalogue (extend `EventBus.gd`); document each signal's args.
- [x] Implement `GameManager` state transitions + `scene_transition_requested` handling with a fade/loading screen hook.

### Phase 02.2 — Content registry
- [x] Implement `ContentRegistry` (scan dir, load defs, index by `id`, warn on dup ids).
- [x] Implement JSON↔Resource hydration for `data/*.json` (so bulk content can be JSON).
- [x] Instantiate one registry per def type at boot; expose `get(id)` / `all()` / `filter(tag)`.

### Phase 02.3 — Base components & service locators
- [x] Finalize `Interactable` (prompt, hold, can/do interact) used by 06/08.
- [x] Finalize `DetectionSensor` and `Minigame` base contracts (impl lands in 04/07).
- [x] Lightweight `Services` access for managers (no sideways manager refs).

### Phase 02.4 — Schema versioning hooks
- [x] Add `schema_version` constants and a migration entry-point used by 16.

## Tests (GUT)
- `test_event_bus_contract.gd` — all documented signals exist with expected arg counts.
- `test_content_registry.gd` — drop a temp def into a scanned dir → `registry.get(id)` returns it (proves FR-02-5).
- `test_registry_duplicate_ids.gd` — duplicate ids are detected and reported.
- `test_gamemanager_states.gd` — illegal transitions are rejected; legal ones emit the right signals.

## Definition of Done
- [x] FR-02-1..6 satisfied; phases checked; tests green.
- [x] A README note in `game/systems/` (done) accurately maps folders→lists.
- [x] "Add content without code" demonstrated by a passing registry test.
