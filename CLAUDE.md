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

## Deferring blocked work
Do everything a task **can** complete now; never fake or half-build a system that a **later** task owns.
When a sub-item is genuinely blocked by a not-yet-built task, **defer it** — but leave a trail so it's not lost:

- **In the current task:** keep the blocked sub-item unchecked (or its DoD `[~]`) and expose a clean
  **hook/seam** for the future task to wire — a signal/method/duck-typed call + a `TODO[NN]:` tag naming
  the blocking list. Don't branch core logic on it or stub a pretend version.
- **In the blocking task's doc** (`docs/tasks/NN_….md`): add a banner at the top —
  `> **↩ From MM (This Task):** …` — naming the exact hook to wire and ending with *"come back and tick
  `<item>` in `MM_….md`."* That arrow is the greppable breadcrumb: `rg "↩ From"`.
- **When the blocking task runs:** wire the hook, then go back and tick the original item + refresh its
  progress note. A milestone gate (M0–M5) is met only once **every** task it spans — including these
  deferred slices — has landed.

*Example (task 06):* obstacles call the task-07 `Minigame` contract but ship no overlay — 06 kept the
consequence logic tested behind a hook and added `↩ From 06` banners to `07`–`13` for the deferred halves.

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
  so they're headless-deterministic. **Complete (`[x]`):** the manual F6 "feel" playtest
  (`game/scenes/player/PlayerGreybox.tscn`) was signed off **2026-06-30**. That playtest surfaced a latent
  bug — `project.godot [input]` had been authored in **Godot-3 dict format** (`{"type":"key","keycode":N}`),
  which Godot 4 silently drops, leaving every keyboard/mouse action unbound (only mouse-look worked); fixed
  by regenerating the section as native `Object(InputEventKey,…)` via `ProjectSettings.save()`.
  *(Pre-existing, unrelated: `test_carry_system.gd` `preload`s a not-yet-existing `Inventory.gd` (task 08)
  → GUT ignores that one script; suite still exits 0.)*
- **04 — Stealth & Detection:** **code + automated DoD complete & verified green** on Godot 4.6.3
  (headless GUT **64/64**). Fleshed out `game/systems/stealth/DetectionSensor.gd` into the legibility
  core: **pure, deterministic seams** (`is_in_cone`, `distance_factor`, `movement_factor`,
  `compute_fill_rate`, `step_fill`, `state_for_fill`/`step_state`, `hearing_bump`) wrapped by thin
  node glue (`_physics_process` cone test + **multi-ray LoS that doubles as cover** → visibility
  fraction; `_sample_light_level` via `&"shadow"` Area3D; `_on_noise_emitted` sound channel). The
  **5-state machine** runs Unaware→Suspicious→Searching→Alerted (fill thresholds) with
  **Alerted/Pursuit latched** ("full detection commits to alert", GDD §8.3) and Suspicious/Searching
  recovering on decay; sound alone is capped below Alerted. **EventBus stayed frozen** — it already
  declared `detection_changed`/`player_spotted`/`noise_emitted` (locked by the contract test), so no
  signal changes. **No magic numbers:** all curve/threshold tunables live in a new `DetectionConfigDef`
  (+ `default_detection.tres`), registered as an **11th `Content` registry** (`Content.detection`);
  per-actor cone/hearing geometry comes from `EnemyDef` (added `default_guard.tres`). Readability HUD
  widgets are deferred to task 15 (this ships the signal data + a dev `DetectionConeDebug` wedge); AI
  behaviors that consume `state`/`last_seen_position`/`last_heard_position` are task 05; PURSUIT
  escalation is task 10. **Residual (`[~]`):** the manual F6 "feel" playtest on the new
  `game/scenes/player/DetectionGreybox.tscn` (walk a cone, hug shadow, recover by breaking LoS) — mark
  `[x]` after in-engine sign-off, mirroring task 03.
- **05 — AI Actors:** **M0 guard core + Phase 05.2 coordination — code + automated DoD complete &
  verified green** on Godot 4.6.3 (headless GUT **93/93**, +6 task-05 tests). Fleshed out
  `game/systems/ai/GuardAI.gd` (`CharacterBody3D`) into a state machine (PATROL/INVESTIGATE/SEARCH/
  COMBAT/DOWNED) driven by its child `DetectionSensor` via **pure deterministic seams**
  (`next_waypoint_index`, `ai_state_for_detection`, `behavior_severity`, `reached`, `tick_timer`,
  `investigate_next`/`search_next`, `search_offset`, `within_propagation_radius`) + thin steering
  glue: loops a waypoint route, peels off to investigate `last_seen`/`last_heard`, does a local
  **sweep** around the contact, and **recovers** (drops back to patrol when the lead goes stale).
  **Post-review fix:** detection reactions are now **escalate-only** — a rising meter promotes the
  guard, but decay-driven downgrades no longer yank it out of an in-progress investigate/search
  (those wind down on their own timers, so FR-05-1's loop actually completes); non-combat leads
  route through INVESTIGATE first so SEARCH sweeps a real ring (`search_radius`) rather than freezing
  in place. Regression-locked by `test_guard_detection_reaction.gd`. `take_down()` drops a discoverable
  **`Body`** (`game/systems/ai/Body.gd`, group `&"body"`, `concealed` flag + drag/hide hook for 08)
  and arms a **`RadioCheckin`** (`game/systems/ai/RadioCheckin.gd`, fakeable-count → `alarm_tripped`).
  Guards scan their cone for un-concealed bodies (`body_discovered`) and **propagate** alerts to
  nearby guards on a teammate's spot/search/body-find. **EventBus stayed frozen** — it already
  declared `body_discovered`/`alarm_tripped`/`player_spotted`/`detection_changed` (locked by the
  contract test), so no signal changes. **No magic numbers:** behavior tunables live in a new
  **`AIConfigDef`** (+ `default_ai.tres`) registered as a **12th `Content` registry** (`Content.ai`);
  per-actor senses/health/speed in `EnemyDef`, now with a `tier` + pure `scaled(mult)` for
  data-driven difficulty (FR-05-9). Dev greybox `game/scenes/ai/GuardGreybox.tscn` (direct-steer,
  no nav-mesh bake). **Deferred (↩ notes added to the blocking task docs):** **05.3** full sensor
  roster (cameras/operator/dogs/civilians/inspector → 06 keycards / 11 population), **05.4** combat AI
  (`_tick_combat` is a converge-only stub → task 10), **05.5** perf round-robin (→ 11). **Residual
  (`[~]`):** the manual F6 "feel" sign-off on `GuardGreybox.tscn` — mark M0 DoD `[x]` after it,
  mirroring tasks 03/04.
- **06 — Heist Mechanics & Obstacles:** **obstacle catalogue — code + automated DoD complete &
  verified green** on Godot 4.6.3 (headless GUT **112/112**, +19 task-06 tests). The puzzle-box
  catalogue is data-driven: a new **`ObstacleDef`** (`id`, `category` enum, `difficulty_tier`,
  `valid_solutions`, `noise_by_solution`, shared tunables + `params`) registered as the **13th
  `Content` registry `Content.obstacles`** (16 authored `.tres` archetypes). 13 `Interactable`
  subclasses in `game/systems/obstacles/` extend a small `Obstacle` base (def resolution + the
  `solution_set()`/`difficulty()` query API that 11/13 will read + frozen-EventBus/group effects) via
  **pure static seams**: `Lock.snap_chance`/`should_snap` (consumable `PickPouch`),
  `HackTarget.in_proximity`/`step_progress` (proximity-lock pause/resume; camera loop-vs-disable; e-lock
  power-cut), `Safe.can_skip` (combo-clue bypass), `FuseBox.affects`/`cut_power` (zone power-cut + backup
  timer + `noise_emitted` investigate-draw), plus `KeycardDoor`/`LaserGrid`/`DisplayCase`/
  `ControllableLight`/`BreachPoint`/`MotionSensor`/`PressurePlate`/`BiometricLock`/`SilentAlarm`.
  **EventBus stayed frozen** (its contract test still passes) — zone power uses a `&"powered_device"`
  group + `power_zone`, loud actions reuse `alarm_tripped("loud")`/`noise_emitted`, readability uses
  local signals. **No magic numbers** — tunables live in `ObstacleDef`/`params`; added `lockpicking`/
  `hacking` `AttributeDef`s. **Task-05 handoff closed:** `EnemyDef.carried_item` + `inspector.tres` carry
  `&"vault_keycard"`, gating `keycard_door.tres` (FR-05-7). **Deferred (↩ notes added to the blocking
  docs):** minigame overlays → 07 (obstacles call the existing `Minigame` contract; the outcome is an
  input to the tested consequence seam — no fake solver), inventory/consumables/held-cards → 08,
  gadgets/weapons (glasscutter/stethoscope/EMP/cloner/breach charges/light-shoot) → 09/10, solution-set
  **consumption** + solvability + clue placement → 11 (FR-06-10), Intel reveal → 13. **Residual
  (`[~]`):** the F6 "feel" sign-off on `game/scenes/obstacles/ObstacleGreybox.tscn` (the fuse→camera/
  e-lock power-cut and the timed e-lock hack are operable now), mirroring tasks 03/04.
- **07 — Minigames:** **all six frameworks — code + automated DoD complete & verified green** on
  Godot 4.6.3 (headless GUT **148/148**, +36 task-07 tests). A `Minigame` (`Control`) base
  (`game/systems/minigames/`) + six subclasses — `LockpickMinigame` (rotate-to-arc + snap),
  `HackMinigame` (node-routing under a soft timer + proximity pause, non-modal), `SafeCrackMinigame`
  (dial clicks + wheels + stethoscope), `KeypadMinigame` (Mastermind deduction + found-code),
  `PickpocketMinigame` (timing meter), `DrillMinigame` (tension-manager overlay over `BreachPoint`) —
  each exposing its scalable maths as **pure static seams** (unit-tested) under thin code-built overlay
  glue; **keyboard + gamepad** via built-in `ui_*` actions (no InputMap edits), so FR-07-9 is met and
  EventBus stayed frozen. The base runs a clean lifecycle (`configure`→`begin`→`solved`/`failed`/`aborted`
  **once** via a `_finished` latch; optional world-pause; `ui_cancel` abort). **No magic numbers:** all
  tunables live in a new **`MinigameConfigDef`** (+ `default_minigame.tres`) registered as the **15th
  `Content` registry `Content.minigames`**; added the missing **`pickpocketing`** `AttributeDef`. A
  **`MinigameHost`** driver maps `kind → overlay` (a `preload`ed const map — bare `class_name`s aren't
  const-valid), injects difficulty (`obstacle.difficulty()`) + attribute (`TODO[12]`, 0 for now) + gear
  (`TODO[09]`, empty for now), and routes the outcome back through one polymorphic
  **`Obstacle.apply_minigame_result(kind, success)`**. **Obstacle wiring (closes the `↩ From 06` overlay
  slices):** `minigame_requested(kind)` was lifted to the `Obstacle` base; `Lock` (interact→lockpick),
  `Safe` (dial), `DisplayCase` (e-lock hack), and `HackTarget` **keypad** (Mastermind; e-locks/cameras
  keep their in-world proximity timer) now request overlays; `BreachPoint.interact` requests the drill
  gauge. The six task-06 obstacle consequence seams + their 112 tests stayed untouched. Dev greybox
  `game/scenes/minigames/MinigameGreybox.tscn` (+ reusable `MinigameHost.tscn`). **Deferred (↩ notes
  added to `05`/`11`):** the **pickpocket→NPC** attach point (needs a pickpockable civilian → 05.3
  roster / 11 population); the framework ships complete with `failed("caught")` as the suspicion hook.
  **Residual (`[~]`):** the F6 "feel" sign-off on `MinigameGreybox.tscn`, mirroring 03/04.
