# CLAUDE.md — Nine Lives

Guidance for Claude (and humans) working in this repo. Read this first, then the
docs it points to. Keep it short; link, don't duplicate.

## What this is
**Nine Lives** is a solo **first-person stealth-heist roguelite** in **Godot 4.6
(Forward+)**, GDScript-primary. You pull contracts in one unbroken **Streak** until
the law Catches you; the run's loot is lost but your **Legacy** carries forward and
each "life" you come back sharper.

- **Core loop:** Streak (contract → contract) → Catch → bank **Legacy** → spend it in
  the Hideout → next Streak is stronger.
- **Three currencies:** **Notoriety** (run reputation/multiplier), **Take** (in-run cash),
  **Legacy** (permanent meta-currency).
- **Locked pillars** (`docs/DESIGN_DECISIONS.md`): first-person · cover-shooter when loud ·
  grounded crime (no supernatural) · 3 currencies · **strict saves** (no mid-mission
  save-scum) · no disguises · **hybrid procedural** levels.
- **Data-driven:** content (loot, gear, edges, perks, archetypes, objectives, modifiers,
  enemies, attributes, stations, intel) is `Resource`/JSON indexed by a unique `id`, so
  expansions ship as **data, not code**.

Canonical design lives in `docs/GDD.md`; build against `docs/ARCHITECTURE.md`.

## Run / build / test
> ⚠️ Requires **Godot 4.6** on `PATH` as `godot`. (Not installed in every dev sandbox —
> if `godot` is missing, code/scene/test files can still be authored but not run.)

- **Open / play:** open the folder in the Godot 4.6 editor (Forward+). Boot scene is
  `res://game/scenes/main/Main.tscn`, which hands off to the Main Menu.
- **Tests (headless GUT):** `bash tools/scripts/run_tests.sh`
- **Doc-link lint:** `bash tools/scripts/check_docs.sh`
- CI (`.github/workflows/ci.yml`) runs both on push/PR.

## Architecture in one screen
**10 autoload singletons** (`project.godot [autoload]`, loaded top-to-bottom — order matters):

| # | Autoload | Role |
|---|----------|------|
| 1 | `EventBus` | Signals only, **zero logic**. The nervous system; everything connects here. |
| 2 | `Content` | Content-registry hub: one `ContentRegistry` per `*Def` type, scanned at boot, indexed by `id`. |
| 3 | `GameManager` | App state machine `BOOT→MAIN_MENU→HIDEOUT→MISSION→MISSION_RESULTS`; owns scene swaps. |
| 4 | `InputManager` | Remappable actions (KB+M + gamepad); persists rebinds to `user://settings.cfg`. |
| 5 | `SaveManager` | 10-slot I/O, autosave, `scan_slots()` (drives the Continue button). |
| 6 | `ProgressionManager` | Permanent account: Legacy, attributes, unlocks, Hideout state, Stash. |
| 7 | `RunManager` | Current Streak: Notoriety, level, Edges, Heat, Take, Job Map, `committed`. |
| 8 | `MissionGenerator` | Seeded hybrid-procedural assembly + population + solvability validation. |
| 9 | `AudioManager` | Dynamic music layers + SFX/bus routing. |
| 10 | `SettingsManager` | Graphics/audio/gameplay options + `ConfigFile` persistence (controls owned by InputManager). |

**Rules of the road**
- **Dependency rule:** managers depend *downward* only (e.g. `RunManager` reads
  `ProgressionManager`, never the reverse). All *sideways* comms go through `EventBus`.
  No two managers hold hard references to each other's mutable state.
- **Scene swaps go through `GameManager`** — never ad-hoc `change_scene` in gameplay code.
- **Add signals in `EventBus.gd` only**, document them, keep that file logic-free.
- **Content registries** (`Content` autoload + `systems/core/ContentRegistry.gd`) scan a folder
  of `*Def` resources at boot and index by `id` (lowercase_snake). New content file → appears
  automatically, no code edit.

## Folder map
```
game/
  autoload/      # the 10 singletons above
  systems/       # reusable gameplay code by domain (stealth, AI, inventory, …)
  scenes/        # scene-local scripts + .tscn (main, menu, hideout, mission, player, ui)
  resources/
    _defs/       # Resource schemas (LootDef, GearDef, EnemyDef, …)
    <category>/  # .tres instances per category
  data/          # bulk JSON content (alt to .tres)
  prefabs/       # hand-authored modular level sections
  assets/        # models/audio/fonts/materials (+ ASSET_MANIFEST.csv, CREDITS.md, ART-TODO.md)
  tests/         # GUT: unit/ + integration/ (+ .gutconfig.json, helpers/)
docs/            # GDD, ARCHITECTURE, DESIGN_DECISIONS, STYLE_GUIDE, ASSET_PIPELINE, TESTING, tasks/
tools/scripts/   # run_tests.sh, check_docs.sh
addons/gut/      # vendored GUT (Godot Unit Test)
```

## Conventions (full text: `docs/STYLE_GUIDE.md`)
- **Static typing everywhere** it's cheap: `var hp: int = 100`, typed params/returns.
- **Naming:** `PascalCase` classes/`class_name`; `snake_case` vars/functions; `SCREAMING_SNAKE_CASE`
  consts/enums; private members prefixed `_`. Content `id`s are `lowercase_snake` `StringName`.
- **One `class_name` per file**, file named after the class (`GuardAI.gd` → `class_name GuardAI`).
  *(Autoload scripts are the exception — they have no `class_name`; they're reached by autoload name.)*
- **Every script opens with a `##` doc comment** stating its job and the task list it belongs to.
- **`TODO[NN]:` tags** where `NN` is the sub-task-list number, so work is greppable: `rg "TODO\[05\]"`.
- **No magic numbers in logic** — tunables live in the relevant `*Def` resource or `data/*.json`.
- **Signals over polling.** Cross-system → `EventBus`; local parent/child → direct signals.
- **New content = new `.tres`/JSON with a unique `id`.** Never branch core code on an `id`; branch on
  a *property* of the def.

## Testing
GUT under `game/tests/{unit,integration}`, files `test_*.gd` extending `GutTest`, configured by
`game/tests/.gutconfig.json`. Workflow: write/locate the test first → implement until green → tick the
checkbox in the task list. Keep tests headless-safe (no editor-only deps).

## Workflow
- Pick the **lowest-numbered unblocked** list in `docs/tasks/00_MASTER_TASKLIST.md`; do phases in order.
- Branches `feature/NN-short-desc`; commits `NN: imperative summary` (e.g. `04: add cone-fill modifier`).
- A list is `[x]` only when its Definition of Done is met and its tests are green. Milestone gates **M0–M5**
  also need the manual playtest checklist signed off.
- **Checkbox legend:** `[ ]` not started · `[~]` in progress · `[x]` DoD met.

## Task progress notes
- **01 — Project Setup & Tooling:** authoring complete (9 autoloads incl. the new `SettingsManager`;
  `Main.tscn` → placeholder Main Menu; InputManager gamepad defaults + runtime rebind + `settings.cfg`
  persistence; SettingsManager schema/persistence; GUT vendored + 3 new tests). **In-engine verification
  (open editor, regenerate `.godot/`, green `run_tests.sh`) is pending a machine with Godot 4.6** — those
  DoD boxes are marked `[~]` in `docs/tasks/01_project_setup.md` until confirmed. Mark them `[x]` after a
  clean editor open + green test run. **Update 2026-06-29:** headless GUT now runs **green on
  Godot 4.6.3** (`.godot/` regenerated via `--import`), and the interactive "open editor → reach
  Main Menu" smoke (FR-01-2) passed — so **01 is complete** (`[x]`). Only residual: bare `godot`
  on PATH for the convenience `run_tests.sh`/CI (the User PATH entry points at the `.exe` file, not
  its directory; a session restart is also needed).
- **02 — Core Architecture & Data Framework:** **complete & verified green** on Godot 4.6.3 (headless
  GUT 22/22). Added a **10th autoload `Content`** (content-registry hub — one generic `ContentRegistry`
  per def type, in `game/systems/core/`), a `Services` static locator, a validated `GameManager` state
  machine + fade hook, the `EventBus.game_state_changed` signal, and a `SaveManager.migrate()` schema
  hook. Fixed a latent `01` bug: `SettingsManager.load()` shadowed Godot's global `load()` → renamed
  `load_config()`.
- **03 — Player Controller & Camera (FP):** **code + automated DoD complete & verified green** on
  Godot 4.6.3 (headless GUT **41/41**). Filled in `game/scenes/player/PlayerController.gd` (+ new
  `PlayerController.tscn`): locomotion/stamina, Stand/Crouch/Prone (collider+eye lerp, ceiling-blocked
  stand-up), clamped mouse + gamepad-axis look (`SettingsManager` sens/invert, refreshed on
  `settings_changed`), collision-safe lean, interaction ray (tap/hold), surface-tagged footstep noise on
  `EventBus.noise_emitted` with Silence scaling, and task-08 carry hooks. **No magic numbers** — all
  tunables in a new `PlayerConfigDef` (`game/resources/_defs/`) + `default_player.tres`; added
  `stamina`/`silence` `AttributeDef` instances and two gameplay settings (`crouch_toggle`/`sprint_toggle`).
  **EventBus stayed frozen** (its contract test asserts the exact signal set + zero methods), so player
  readability uses **local signals** + the `&"player"` group; detection (04) reads stance via that group.
  Tests favor pure seams (`compute_noise_radius`, `update_stamina`, `update_hold`, `_resolve_interactable`)
  so they're headless-deterministic. Only open item: the manual "feel" playtest (`[~]`) — run
  `game/scenes/player/PlayerGreybox.tscn` (F6). *(Pre-existing, unrelated: `test_carry_system.gd`
  `preload`s a not-yet-existing `Inventory.gd` (task 08) → GUT ignores that one script; suite still exits 0.)*
