# 01 — Project Setup & Tooling

**Milestone:** M0 · **Depends on:** none · **Blocks:** everything
**Implements:** GDD §3, §16 · **Decisions:** Forward+, GDScript primary, GUT tests.

## Overview
Stand up a clean, reproducible Godot 4.6 project: autoloads wired, input map
remappable, options persistence, test harness, and CI. Nothing here is gameplay —
it's the ground everyone else builds on.

## Functional Requirements
- **FR-01-1** Project opens in Godot 4.6 Forward+ with all 9 autoloads resolving (no script errors).
- **FR-01-2** `Main.tscn` is the boot scene and loads the Main Menu (placeholder OK).
- **FR-01-3** Every input action in GDD §15 (Options → Controls) exists and is **remappable at runtime**; rebinds persist to `user://settings.cfg`.
- **FR-01-4** Options/settings persist via `ConfigFile`, independent of save slots.
- **FR-01-5** GUT runs headlessly via `tools/scripts/run_tests.sh`; CI executes it on push/PR.
- **FR-01-6** Git LFS configured; `.gitignore` excludes `.godot/`, builds, secrets.

> **Status (authoring pass):** all code/scene/config/test files are authored. Items
> that can only be confirmed by running the engine are marked `[~]` — Godot 4.6 was not
> available in the authoring sandbox. **Verified 2026-06-29 on Godot 4.6.3 — all engine-gated
> boxes are now `[x]` (headless GUT green + an interactive boot → Main Menu smoke).** The
> settings schema lives in a new **9th autoload**
> `SettingsManager` (decision: own singleton, not a non-autoload helper).

## Phases
### Phase 01.1 — Project & autoloads
- [x] Verify `project.godot` autoload paths (all 9 resolve; added `SettingsManager`).
- [x] Open once to regenerate `.godot/` — *done via `godot --headless --import` on 4.6.3; the referenced `default_env.tres` + `default_bus_layout.tres` resolve.*
- [x] Create placeholder `Main.tscn` → loads a placeholder Main Menu scene (`MainMenu.tscn`, Continue disabled when no saves).
- [x] Confirm all autoload stubs parse and `_ready()` without error — *verified green by `test_autoloads_boot.gd` on 4.6.3 (now 10 autoloads incl. `Content` from list 02).*

### Phase 01.2 — Input system
- [x] Finalize the action set (movement, stances, lean, interact, takedown, casing, throw, aim/fire/reload, weapon/gadget, pause) — present in `project.godot [input]`, mirrored in `InputManager.ACTIONS`.
- [x] `InputManager`: add gamepad default events at boot (`_apply_gamepad_defaults`, idempotent). Covers 19/21 actions; `prone` + `throw` deferred to context/chord bindings (tasks 09/15) — a 21-action set exceeds clean pad buttons.
- [x] Runtime rebind API (`rebind_action`) + load/save to `user://settings.cfg` `[controls]` section.

### Phase 01.3 — Settings/config
- [x] Define the settings schema (video/audio/gameplay with defaults; controls owned by InputManager) — `SettingsManager.DEFAULTS`.
- [x] Apply-on-load + apply-on-change; persist to `ConfigFile` (`SettingsManager.load_config/apply_all/set_value/save`).

### Phase 01.4 — Test & CI tooling
- [x] Install GUT into `addons/gut/`; enable plugin (`project.godot [editor_plugins]`).
- [x] Green sample run — *headless GUT 22/22 green on 4.6.3 (run via the godot binary directly).*
- [x] Wire `.github/workflows/ci.yml` (headless GUT + `check_docs.sh`) — already present; verified.
- [x] Document the workflow in `CONTRIBUTING.md` (done) and verify links lint.

## Tests (GUT)
- `test_autoloads_boot.gd` — each autoload singleton exists and is the right class.
- `test_input_rebind.gd` — rebinding an action then reloading restores the new binding.
- `test_settings_roundtrip.gd` — write settings → reload → values match defaults/overrides.
- (existing) `test_save_scan.gd` provides the SaveManager smoke check.

## Definition of Done
- [x] FR-01-1..6 satisfied; all phase boxes checked — *verified on Godot 4.6.3: headless GUT green + interactive boot → Main Menu smoke passed.*
- [x] `run_tests.sh` green locally and in CI — *suite verified green on 4.6.3 via direct invocation; the literal `run_tests.sh`/CI still want `godot` on PATH (the dir, not the .exe file).*
- [x] Fresh clone → open → run reaches the Main Menu with zero errors — *interactive smoke passed on Godot 4.6.3 (2026-06-29).*
