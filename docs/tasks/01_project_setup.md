# 01 — Project Setup & Tooling

**Milestone:** M0 · **Depends on:** none · **Blocks:** everything
**Implements:** GDD §3, §16 · **Decisions:** Forward+, GDScript primary, GUT tests.

## Overview
Stand up a clean, reproducible Godot 4.6 project: autoloads wired, input map
remappable, options persistence, test harness, and CI. Nothing here is gameplay —
it's the ground everyone else builds on.

## Functional Requirements
- **FR-01-1** Project opens in Godot 4.6 Forward+ with all 8 autoloads resolving (no script errors).
- **FR-01-2** `Main.tscn` is the boot scene and loads the Main Menu (placeholder OK).
- **FR-01-3** Every input action in GDD §16.6 exists and is **remappable at runtime**; rebinds persist to `user://settings.cfg`.
- **FR-01-4** Options/settings persist via `ConfigFile`, independent of save slots.
- **FR-01-5** GUT runs headlessly via `tools/scripts/run_tests.sh`; CI executes it on push/PR.
- **FR-01-6** Git LFS configured; `.gitignore` excludes `.godot/`, builds, secrets.

## Phases
### Phase 01.1 — Project & autoloads
- [ ] Verify `project.godot` autoload paths; open once to regenerate `.godot/`.
- [ ] Create placeholder `Main.tscn` → loads a placeholder Main Menu scene.
- [ ] Confirm all 8 autoload stubs parse and `_ready()` without error.

### Phase 01.2 — Input system
- [ ] Finalize the action set (movement, stances, lean, interact, takedown, casing, throw, aim/fire/reload, weapon/gadget, pause).
- [ ] `InputManager`: add gamepad default events for every action at boot.
- [ ] Runtime rebind API + load/save to `user://settings.cfg`.

### Phase 01.3 — Settings/config
- [ ] Define the settings schema (graphics/audio/controls/gameplay) with defaults.
- [ ] Apply-on-load + apply-on-change; persist to `ConfigFile`.

### Phase 01.4 — Test & CI tooling
- [ ] Install GUT into `addons/gut/`; enable plugin; green sample run.
- [ ] Wire `.github/workflows/ci.yml` (headless GUT + `check_docs.sh`).
- [ ] Document the workflow in `CONTRIBUTING.md` (done) and verify links lint.

## Tests (GUT)
- `test_autoloads_boot.gd` — each autoload singleton exists and is the right class.
- `test_input_rebind.gd` — rebinding an action then reloading restores the new binding.
- `test_settings_roundtrip.gd` — write settings → reload → values match defaults/overrides.
- (existing) `test_save_scan.gd` provides the SaveManager smoke check.

## Definition of Done
- [ ] FR-01-1..6 satisfied; all phase boxes checked.
- [ ] `run_tests.sh` green locally and in CI.
- [ ] Fresh clone → open → run reaches the Main Menu with zero errors.
