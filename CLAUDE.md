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
- **Add UI control text in greyboxes**, When making greybox playtest sandboxes, make sure the UI is complete
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
- **08 — Loot & Inventory:** **code + automated DoD complete & verified green** on Godot 4.6.3
  (headless GUT **178/178**, +30 task-08 tests). A new **`game/systems/inventory/`** domain:
  `Inventory` (`RefCounted`, owned by `PlayerController`) is the two-axis carry brain — weight/
  volume/hand-slot caps (`can_pick_up`), pocketable-vs-bagged pickup routing, key-item tracking,
  body-drag, throwing, and secure/lose bookkeeping — matching the pre-existing fixed-contract
  `test_carry_system.gd` exactly. **Correction during review:** a carried `Bag` occupies one hand
  slot (GDD §10.1 lists "gold bag" as a hand-slot example, not weightless-on-the-back), which
  makes carrying a bag and dragging a `Body` naturally mutually exclusive under the 2-slot cap
  with zero special-case code — `test_body_drag.gd` locks this in. `LootPickup`/`DropPoint`/
  `Escape` are `Interactable`s; `DropPoint.secure_from()`/`receive_bag()` are pure banking seams
  a real `ThrownBag` (`RigidBody3D`) physics landing and a headless test both call identically,
  so FR-08-4's throwing is fully unit-tested with **zero physics simulation**. **EventBus stayed
  frozen** — reuses the 4 pre-existing loot signals (`loot_picked_up`/`loot_secured`/
  `carry_changed`/`objective_updated`) exactly as declared; everything else (pickup-rejected
  feedback) is a local signal, matching `Obstacle.state_changed`/`Lock.pick_snapped`. **No magic
  numbers:** new carry tunables live on the existing `PlayerConfigDef` (a single directly-
  assigned resource, not Content-registered, matching how it's already used); a new
  `strength.tres` `AttributeDef`. `RunManager.add_notoriety`/new `add_take()` now do real base
  accumulation (`TODO[12]`/`TODO[14]` mark the multiplier/level-up/percentage enrichment those
  tasks still own — the precedent `Lock.resolve_attempt`'s `lockpicking_level` parameter already
  established); `ProgressionManager.add_to_stash()` backs FR-08-9. **Closed the task-05/06 duck-
  type hooks without touching any obstacle code:** `Obstacle.gd`/`BiometricLock.gd`/`Lock.gd`/
  `HackTarget.gd` were untouched except `HackTarget._complete()`'s one new `data_loot` branch —
  `PlayerController` grew `has_item()`/`is_carrying_keyholder()`/`add_loot()`, exactly the shape
  those duck-types were already calling. `Body` now `extends Interactable` (was bare `Node3D`) —
  a runtime-spawned body previously had no collider/mesh at all (confirmed via
  `GuardGreybox.tscn`'s decorative `Body0`, which also had none), so `_ready()` now builds a
  procedural collider always and a placeholder mesh only if a scene author hasn't placed one.
  Dev greybox `game/scenes/inventory/InventoryGreybox.tscn` (+ `InventoryGreyboxDebug.gd`, which
  also wires a real `PickPouch` to the greybox's `Lock`, closing that task-06 stand-in here).
  **Residual (`[~]`):** the F6 "feel" sign-off on `InventoryGreybox.tscn` — this session verified
  the scene loads cleanly headlessly (same baseline renderer noise as `ObstacleGreybox.tscn`) but
  could not drive interactive input; mark `[x]` after a human playtest pass, mirroring 04–07.
- **09 — Loadout, Gear & Gadgets:** **code + automated DoD complete & verified green** on Godot 4.6.3
  (headless GUT **200/200**, +22 task-09 tests). New domain **`game/systems/inventory/`'s sibling
  `game/systems/loadout/`**: `Loadout` (`RefCounted`, owned by `RunManager` via `RunManager.loadout()`,
  read by `PlayerController`) enforces per-slot capacity from a new **`LoadoutConfigDef`** (**16th
  `Content` registry `Content.loadout`**), research-gates equip against `ProgressionManager.unlocked_gear`,
  tracks consumable counts + `restock()` spending `RunManager.take`, exposes `gear_flags()` for the
  MinigameHost, and `validate()` + `to_dict()/from_dict()` (FR-09-8). `Weapon` + `Armor` are pure-ish
  models built from `GearDef.params` (extended with `tier`/`slot_cost`/`max_count`): weapon
  ammo/reload/recoil-spread/`attach()` mods + the **suppressed-vs-loud noise seam** (`fire()` emits the
  frozen `noise_emitted("gunshot")`, feeding 04); armor plate/overflow/regen + weight→`agility_mult`.
  **26 `GearDef` `.tres`** authored (tools, breach drill/thermite/C4, gadgets, weapons, suppressor mod,
  utility, apparel — **no Disguise Kit**, Q6; soft-soled gear's Silence bonus folds into footstep noise).
  Added a `marksmanship` `AttributeDef`. **EventBus stayed frozen** — loadout changes are a local
  `loadout_changed`; gunshots reuse `noise_emitted`. **Closed every `↩ From 06` gadget hook without
  touching obstacle consequence code:** `PlayerController.has_glasscutter()/can_clone_keycard()/
  has_biometric_spoof()` answer from the loadout, `MinigameHost._gear_params()` feeds stethoscope/
  hacking-rig, and a new **additive `BreachPoint.equip_tool()`** folds drill/thermite/C4 upgrade params
  (identity when no gear → the 112 task-06 tests unchanged; new `test_breach_gear.gd` locks it).
  **Deferred (↩ From 09 banners added to 10/11/13/16):** cover-shooter firing/damage-routing consuming
  the `Weapon`/`Armor` models → **10**; Armory/Fence/Workshop station UI → **13**; loadout↔`SaveManager`
  → **16**; found-as-loot + loadout-into-mission + active-throw gadgets → **11**; armor/ammo HUD → **15**.
  **Residual (`[~]`):** the 09 DoD's second bullet ("round-trips through save; weapons/armor feed 10")
  is blocked on 16/10 — the serialization itself round-trips + is tested. *(Update: "weapons/armor feed 10"
  half landed with task 10; only the `SaveManager` wiring is still blocked on 16.)*
- **10 — Going Loud, Combat & Pursuit:** **code + automated DoD complete & verified green** on Godot 4.6.3
  (headless GUT **222/222**, +22 task-10 tests). The going-loud escape gauntlet, built entirely on the
  **already-frozen EventBus** (`alarm_tripped`/`heat_changed`/`pursuit_phase_changed`/`streak_ended` all
  pre-declared — no signal changes). **Pursuit timeline:** a new mission-scoped `game/systems/pursuit/
  PursuitDirector.gd` arms on `alarm_tripped` and escalates phases 0→5 (GDD §8.6) off a response timer via
  **pure static seams** (`start_phase` — loud starts at 1, silent skips ahead; `next_phase`;
  `spawn_budget_for`; `tier_for`), re-emitting `pursuit_phase_changed` + a local
  `reinforcements_requested(tier, count)`. Tunables live in a new **`PursuitConfigDef`** (+
  `default_pursuit.tres`), the **17th `Content` registry `Content.pursuit`**. **Heat/commit (FR-10-3):**
  `RunManager` gained a `_ready` alarm listener + a real `raise_heat()` (clamp 0..1 + `heat_changed`) that
  sets `committed` and raises Heat by the config amount (loud > silent); the payout-multiplier +
  future-contract escalation stay `TODO[11]/TODO[12]`. **Combat core:** new `game/systems/combat/` —
  `Health` (`RefCounted`, pure-ish) routes damage **Armor→Health→DOWNED** with a self-revive window
  (→CAUGHT on lapse) and a **Capture / Get-Out-of-Jail** timing check (consumes the consumable on a pass →
  ESCAPED, else CAPTURED); pure seams `route_damage`/`is_down`/`skill_check_pass`. `PlayerCombat` (`Node3D`
  under `$Head/Hands`) builds live `Weapon`s from `Loadout.weapons()`, fires via camera hit-scan (reuses
  task-09 `Weapon.fire()`'s damage/spread/`noise_emitted("gunshot")` ring + `current_spread(marksmanship)`),
  with pure `blindfire_spread`/`suppressed_spread` seams. **PlayerController** now builds a `Health` pool
  (`PlayerConfigDef.health_base` × Health attr, + a new `Loadout.armor()` plate pool), applies
  `Armor.speed_mult()` to move speed, mounts `PlayerCombat`, exposes `apply_damage()`, and on CAUGHT/CAPTURED
  hands off to 12 (`RunManager.end_streak`) → `GameManager.goto_results` (FR-10-9). **Enemy escalation
  (closes Phase 05.4):** `GuardAI._tick_combat` replaced its converge-only stub with a fighting standoff
  (pure `combat_move_intent`/`should_fire`/`is_dead`) that fires `EnemyDef.loadout`'s Weapon at the player
  and takes `apply_damage` (downs → lethal `Body`). New `EnemyDef` tiers `responder`/`swat`/
  `specialist_shield`/`specialist_sniper` + an armed base guard (data, not id-branching). **Escape win
  (FR-10-8):** task-08 `Escape` banking already secures value on extraction (safe by construction). **No
  magic numbers** — all combat/pursuit tunables in `PursuitConfigDef`; added `health_base` to
  `PlayerConfigDef`. **Deferred (↩ From 10 banners added to 11/15):** reinforcement spawn **placement** +
  `Escape`→results transition → **11**; Pursuit/Heat + ammo/health/armor + Get-Out-of-Jail-bar HUD → **15**;
  Heat→payout-multiplier + the Legacy-conversion formula in `end_streak` → **12**. **F6 "feel" playtest
  signed off 2026-07-02** — going-loud/combat/pursuit verified inside `MissionGreybox.tscn` (`L`=go-loud →
  phases climb, `LMB` fires, reinforcements spawn, damage → Downed → Caught). **Task 10 complete (`[x]`).**
- **11 — Mission Generation:** **code + automated DoD (M1 *and* M2) complete & verified green** on Godot
  4.6.3 (headless GUT **245/245**, +23 task-11 tests). The **integration keystone** that stitches tasks
  04–10 into a fair/legible/solvable/seed-reproducible heist, built as **two stages** so the hard logic is
  headless-testable: `MissionGenerator.generate_layout(contract)` → a pure `MissionLayout` (a new
  **`game/systems/missiongen/`** domain: `MissionAssembler` grid-places sections **overlap-free by
  construction** with sockets matched-or-capped + one M2 cross-link loop; `MissionPopulator` scatters loot/
  patrols/camera-lock hazards/objective/keys/consumables/civilian under designer rules; `MissionBoard`
  builds the escalating 3–5-contract board), validated headlessly by **`MissionValidator`** — graph
  reachability entry→objective→escape + reachable Drop Point with a **key/clue fix-point** (the CI
  solvability gate; a key stranded behind its own door fails, so it's a real proof, not a rubber stamp).
  `build(contract)` **realizes** the layout into a **`MissionController`** (`game/scenes/mission/`) Node3D
  tree GameManager swaps in (procedural greybox floors + spawned guards/obstacles/loot/DropPoints/Escape +
  player). **Data-driven:** new **`SectionDef`** (footprint/socket_count/anchors) → **18th `Content` registry
  `Content.sections`** (`prefabs_meta/`, 6 Bank sections); new **`Contract`** (Resource, `to_dict/from_dict`
  save-ready for 16); `ArchetypeDef` gained id-reference pools (`section_ids`/`objective_ids`/`enemy_roster`/…);
  Bank fully authored + Museum/Warehouse (shared greybox sections pending art) + 8 objectives + 4 modifiers.
  The task-02 `sample_archetype_bank.json` scaffold was superseded by real `.tres` archetypes (removed from
  the scan). **EventBus stayed frozen** — reuses `objective_updated`/`loot_secured`/`mission_completed`/
  `alarm_tripped` + local signals. **Closed the deferred ↩ hooks:** `Escape`→`goto_results` +
  `PursuitDirector.reinforcements_requested`→spawn at reinforce anchors (10); `Obstacle.solution_set()`/
  `difficulty()` consumed for solvability (06, FR-06-10); `MinigameHost.attach_all` over built obstacles (07);
  consumables found-as-loot + `Loadout.validate()` pre-mission in `GameManager.enter_mission` (09); the three
  `PlayerController` thrown/dropped-body spawns now parent under the `&"mission_root"` group (closed its
  TODO[11]); `RunManager.start_new_streak()`→`refresh_board()`. **Deferred (refreshed ↩ notes, per scope):**
  deep **05.3** AI roster behaviors (dogs/operator/civilian-wander — the civilian ships as a pickpockable
  keycard marker) + **05.5** perf profiling; real art prefabs → **18**; daily/seeded contracts → **20**; Job
  Map UI → **13/15**; Heat→payout-multiplier → **12**. **F6 "feel" playtest signed off 2026-07-02**
  (`game/scenes/mission/MissionGreybox.tscn` — a generated Bank plays end to end: slip a cone, clone the
  vault gate, bag loot → Drop Point, Escape). **Task 11 complete (`[x]`).** **Playtest fixes:** the first walk
  surfaced legibility/affordance
  gaps in the greybox *realization* (not the generator) — fixed: guards now render **blue capsules + a
  `DetectionConeDebug` wedge** (the Inspector/keycard-carrier is **gold**), the civilian is a distinct cyan
  box, section tiles ramp blue→amber (no longer clashing with the red Escape), and high-security wings
  reliably get a camera. `MissionGreyboxDebug` now **equips a dev Loadout** (suppressed pistol + keycard
  cloner + lockpick + emp/smoke) so `fire`/gadgets/the **vault keycard door** (opens via the cloner) are
  testable, adds a **debug HUD** (carry / secured / alert / pursuit + a controls cheat-sheet — the real HUD
  is task 15) and an **L = force go-loud** dev key. Also **closed a genuine task-05 wire**: the `takedown`
  input action (default **V**) had **no consumer** — `PlayerController._update_takedown_input()` now drops
  the nearest guard you're facing via the existing `GuardAI.take_down(false)` (leaves a concealable Body
  with the carried keycard). Controls: **F** interact/pick-up · **V** takedown · **T** throw bag · **G**
  drop body · **LMB** fire · **1** weapon · **4** gadget.
- **12 — Progression: Streak & Legacy:** **code + automated DoD complete & verified green** on Godot
  4.6.3 (headless GUT **270/270**, +25 task-12 tests). The roguelite engine, data-driven end to end and
  built on the **already-frozen EventBus** (`notoriety_gained`/`streak_level_up`/`streak_ended` were
  pre-declared + contract-locked — no signal changes). **Config:** a new **`ProgressionConfigDef`**
  (+ `default_progression.tres`), the **19th `Content` registry `Content.progression`**, owns every
  curve (Streak-Level thresholds, performance-bonus fractions, Heat→payout slope, `legacy_floor`, Edge
  rarity weights) — no magic numbers. **`RunManager`** gained the Streak brain as **pure static seams**
  (`level_for_notoriety`, `stack_multiplier`, `draw_edges`, `heat_multiplier_for`, `convert_to_legacy`)
  under thin glue: `add_notoriety` applies held-Edge `notoriety_mult` then draws **1-of-3** Edges on a
  level-up; a new `mission_completed` listener banks objective NP × the performance multiplier
  (no-alarm/stealth from RunManager's own per-mission `alarm_tripped`/`player_spotted` tracking, +
  no-kill/full-clear/speed from the MissionController summary) and bumps `streak_length`; `raise_heat`
  now feeds `heat_multiplier()`; **`end_streak`** converts `Notoriety × Heat-mult → Legacy` (floored),
  banks it via `ProgressionManager.add_legacy`, emits `streak_ended`, records lifetime stats, and resets
  the Streak (FR-12-1..4/9). Held Edges are queried via `edge_modifier_total(key)` and vanish on the
  Catch. **`ProgressionManager`** gained the Legacy sinks: `train_attribute` (spends the `AttributeDef`
  cost curve, raises the level; `attribute_effect` = level × per-level feeds systems) + Legacy Perks
  (`buy_perk`/`can_buy_perk`, prereq + cost gated, permanent, idempotent) + `perk_modifier_total`.
  **Content:** **20 `EdgeDef`** (rarity-tiered GDD §5.1 roster: Silent Hands / Ghost / Mule / Fence
  Connections / …), **8 `PerkDef`** (with a prereq chain nimble→ghost_protocol, thick_skin→juggernaut,
  →legend), and cost curves on all **14** GDD §5.5 attributes (added health/armor/speed/sneak/
  carry_weight/carry_volume/perception). **Closed the deferred `TODO[12]` hooks** (↩ From 06/07/10):
  the Heat→payout multiplier + Legacy-conversion formula in `end_streak`; MinigameHost/Minigame attribute
  injection now returns real levels; `Lock.apply_minigame_result` eases the pick-snap by trained
  Lockpicking (level from ProgressionManager, per-level reduction from the `AttributeDef` — no magic
  numbers). Updated the task-10 `test_secured_safe_on_loud_catch` to the now-real conversion (its own
  comment had deferred it here). **Deferred (↩ notes, per scope):** Take = %-of-cash + the full Notoriety
  economy pass → **14**; per-system consumption of every Edge/Perk *effect* → per-system polish; the
  Hideout **spend** UI → **13**. **Residual (`[~]`):** the M1 "felt" full-loop is the M1 milestone gate
  (needs the Hideout spend UI (13) + menu/save (15/16)) — **not task 12 alone**; the
  Streak→Catch→conversion→board-escalation half is F6-testable in `MissionGreybox.tscn` today. **Task 12
  code-complete (`[x]`).**
- **13 — Hideout & Stations:** **code + automated DoD (M1 *and* M3) complete & verified green** on Godot
  4.6.3 (headless GUT **295/295**, +25 task-13 tests). The between-mission hub, built **manifest-driven**:
  a new **`game/systems/hideout/HideoutManifest.gd`** builds the station list purely from `Content.stations`
  + `ProgressionManager` unlock state, so a `StationDef` .tres + a panel scene = a new station with **no
  code edit** (FR-13-1, proven by `test_station_manifest` — the station-level mirror of FR-02-5). **Manager
  seams (pure static, headless-tested):** `ProgressionManager` gained station unlock (`is/try_unlock_station`
  + `can_unlock_station` — Legacy **or** delivered-special-loot gate), Workshop `research_gear` (+
  `can_research`, optional `params["research_prereq"]`), Fence `convert_stash_item` (+ `convert_value`), and
  `stash_set_bonus_total` (the "read by 12" set-bonus seam); `RunManager` gained the Planning-Table Intel
  line — `buy_intel`/`has_intel`/`revealed_modifiers` keyed by `mission_seed`, hiding a contract's modifiers/
  manifest until bought (FR-13-3/8). **UI:** a **2D `Hideout.tscn`** hub (manifest grid + unlock buttons +
  currency header) + a `StationPanel` base and **8 panels** in `game/scenes/hideout/stations/` (Job Map,
  Training, Workshop, Armory, Legacy Board, Planning Table, Stash, Fence) that thin-wrap already-tested
  manager methods; **plus** a 3D furnished **`HideoutGreybox.tscn`** demo (Phase-1 **Quaternius** furniture +
  a **Casual** character; FP walk WASD+mouselook, `[F]` a station prop → the *same* panel overlay; locked
  props show a red placard and turn green when unlocked — "the safehouse visibly grows"). **EventBus stayed
  frozen** — panels use direct manager calls + local `closed`/`loadout_changed` signals. **Content:** **8
  `StationDef`** (`job_map`/`training`/`workshop` free; `armory`/`legacy_board`/`planning_table`/`fence`
  Legacy-gated; `stash` **loot-gated** on delivering `stash_trophy_painting`) + **3 `IntelDef`**; `LootDef`
  gained a `params` field (Stash `set_bonus`) and `IntelDef` gained `description`/`legacy_cost`. `GameManager`
  New Game/Continue now land in the Hideout (FR-13-11; real save I/O stays `TODO[16]`). **Closed the deferred
  hooks:** `↩ From 06` (Intel reveal → Planning Table), `↩ From 09.1/09.2` (Armory/Workshop/Fence front-ends),
  `↩ From 12` (Training/Legacy-Board front-ends over `train_attribute`/`buy_perk`). **Deferred (per scope):**
  Take-scaling on Intel/Fence → **14**; first-time hints → **22**; loadout/progression↔`SaveManager` → **16**.
  **F6 "feel" playtest signed off 2026-07-04** (hub + all 8 panels + the 3D `HideoutGreybox.tscn` demo;
  headless instantiation of every scene is also smoke-tested by `test_hideout_scenes.gd`) — **Task 13
  complete (`[x]`).** The **M1 milestone gate** itself still needs **15** (menu/HUD) + **16** (save) before
  it's met.
- **14 — Economy & Balancing:** **code + automated DoD (M2 wiring *and* M3 tuning) complete & verified
  green** on Godot 4.6.3 (headless GUT **311/311**, +15 task-14 tests). The three-currency economy, wired
  then *tuned*, built on the **already-frozen EventBus** (reuses `loot_secured`/`notoriety_gained`/
  `heat_changed`/`streak_ended` — no signal changes). **Config:** a new **`EconomyConfigDef`** — the **20th
  `Content` registry `Content.economy`** — is the central balance table, authored **only** as hot-editable
  **`game/data/economy.json`** (loaded via the existing `ContentRegistry` JSON path proven by
  `sample_loot.json`; `resolve()` falls back to schema defaults so headless seams never crash). Owns the
  Take fraction, the Notoriety `bonus_*` multipliers, the Heat→payout slope, the `legacy_floor`, the catch
  model + target bands — no magic numbers. **This is the `↩ From 12` handoff:** task 14 took over the
  economy dials; `ProgressionConfigDef` keeps the streak *structure* (level thresholds, Edge weights).
  **FR-14-2 (Take = %):** `DropPoint.bank()` now banks Notoriety=**full** street value but Take=only the
  `take_fraction` cut (pure seam `EconomyConfigDef.take_cut`); `add_take`'s `TODO[14]` resolved (it stays a
  pure passthrough — the Fence + restock refunds bank their own values; the Fence honours `fence_fraction`).
  **FR-14-3:** `RunManager._econ()` sources the dials; `_on_mission_completed`/`heat_multiplier`/`end_streak`
  read it. `stack_multiplier(flags, cfg)`'s `cfg` was **relaxed to duck-typed** so both `EconomyConfigDef`
  (runtime) and `ProgressionConfigDef` (task-12 tests) work — task-12 pure-seam tests stayed green (they use
  `.new()` defaults). **FR-14-4:** new **`EconomyValidator`** (pure static) range-checks every per-item cost
  `.tres` (loot value / gear research+restock / attribute curves monotonic+sized / perk cost+prereqs / Intel
  prices) **+** the economy dials; `test_data_tables_valid` asserts zero violations and proves it's *not* a
  rubber stamp. Per-item costs stay `.tres` (validated, not migrated) — the user-chosen JSON scope.
  **FR-14-6:** new **`EconomySimulator`** (Monte-Carlo, CLEAN vs LOUD cohorts, seeded/headless) reuses the
  real payout seams (`stack_multiplier`/`heat_multiplier_for`/`convert_to_legacy`) so editing `economy.json`
  moves the sim too; reports Streak-length distribution + Legacy/run + a clean/loud ratio. **FR-14-5
  (stealth-favored tuning, per the user's "not intended to be loud"):** `take_fraction 0.35`, modest
  `heat_multiplier_slope 0.5`, steep `catch_per_heat 0.55`; harness (20k runs/cohort) → **clean mean 4.47
  contracts / ~35.3k Legacy** vs **loud 1.51 / ~13.8k → 2.55× ratio**, min payout = the floor, every Catch
  affords the cheapest Training buy. Intel re-priced to the new Take reality (manifest 1200 / modifiers 1800
  / silent_alarms 2400) so casing stays usable on a clean run. Also **closed a task-12 leftover:** the
  `financier` Perk's `legacy_conversion_mult` is now consumed in `end_streak` (updated the two task-12/08
  tests whose expectations the new Take-% + Heat-slope shifted — like task 12 updated task 10's). **Greybox
  `game/scenes/economy/EconomyGreybox.tscn`** (+ `EconomyGreyboxDebug.gd`) — an FP Economy Sandbox using
  **real heist props** (`safe.glb`) + **Quaternius furniture**: a Vault secures cash (watch the
  Notoriety-full / Take-fraction split live), the five spend-station props open the real `StationPanel`s, and
  dev keys drive the flow (`[H]` silent alarm → Heat↑, `[C]` complete clean contract, `[K]` get Caught →
  convert, `[B]` balancing-harness readout with an ASCII Streak-length histogram). **Deferred (↩):**
  in-mission Take/Heat HUD → **15**; economy↔`SaveManager` → **16**; daily/seeded balance presets → **20**.
  **F6 "feel" playtest signed off 2026-07-04** (headless instantiation of `EconomyGreybox.tscn` is also
  smoke-tested by `test_economy_scenes.gd`) — **Task 14 complete (`[x]`).** The **M2/M3 milestone gates**
  still need their other spanned tasks before they're met.
- **15 — UI/UX, HUD & Menus:** **code + automated DoD complete & verified green** on Godot 4.6.3 (headless
  GUT **331/331**, +20 task-15 tests). All UI is **code-built** (the `Hideout.gd`/`StationPanel.gd` house
  pattern) behind a shared **`UITheme`** (`game/scenes/ui/UITheme.gd`) that assembles a `Theme` from the
  **Kenney Future font + `ui/kit_rpg` 9-slice textures** with flat fallbacks, plus a shared palette (incl.
  the grey→yellow→orange→red detection band). **Menus (Phase 15.1):** rebuilt **`MainMenu`** (exactly four
  items; Continue disabled via the pure seam `MainMenu.continue_enabled(count)`; Exit via `ConfirmPopup`)
  routes New Game/Continue into a shared **`SlotPopup`** (`NEW`/`LOAD`; each row renders
  `SaveManager.slot_summary()` through the pure `SlotPopup.format_slot()` → five fields / "Empty";
  Overwrite + per-slot Delete confirmed). **Full Options (Phase 15.3, FR-15-4):** **`Options.gd`**
  `TabContainer` — Graphics/Audio/**Controls (live KB+M & gamepad remap** over `InputManager.ACTIONS` →
  `InputManager.rebind_action`)/Gameplay-Accessibility/System — every control reads/writes
  `SettingsManager.get_value/set_value` (already live-applies + persists); **`SettingsManager.DEFAULTS`
  extended to the full GDD §15.2 schema** (render_scale/shadows/fov/gamma/motion_blur/camera_shake, ui/
  ambience/subtitles, colorblind/reduce_flashing/aim_assist/vibration/language) with `render_scale` applied
  to the viewport + `fov` pushed to the player camera on `settings_changed`. **HUD (Phase 15.2/15.4,
  Q1):** **`HUD.gd`** (`CanvasLayer`, `PROCESS_MODE_ALWAYS`) mounts the **combined `CompassEye`** — an eye
  that fills grey→red with the strongest detection meter, ringed by a directional tick that points at the
  most-alarming guard (resolved via `instance_from_id(actor_id)` on the frozen `detection_changed`), with a
  redundant state **symbol** so it's not colour-only (FR-15-7) — plus carry (W/V vs caps + FULL), objective +
  **secured-vs-remaining** (new `MissionController.loot_total_value()`), a Pursuit/Heat strip, and a **loud
  block** (health/armor/ammo) gated by the pure `HUD.loud_visible()`; an **on-world `NoiseRingSpawner`**
  draws the noise ring (FR-15-5). The HUD is mounted by `MissionController.realize()` (the
  `MissionGreyboxDebug` stand-in label was trimmed to a bottom controls cheat-sheet). **Pause + results:**
  **`PauseMenu`** (owned by the HUD via the `pause` action; pauses the tree, frees the mouse) surfaces the
  **Q5 commit messaging** — a clean bug-out (uncommitted) returns to the Hideout keeping loot/Streak, but
  once `RunManager.committed` leaving resolves as the **Catch** (`end_streak` → results); **`MissionResults.gd/
  .tscn`** (the path `GameManager.MISSION_RESULTS_SCENE` already referenced) summarizes the escape/Catch +
  Legacy payout from a new `GameManager.pending_results` dict (fed by `PlayerController._on_health_state_changed`
  on a Catch). **EventBus stayed frozen** — reuses `detection_changed`/`pursuit_phase_changed`/`heat_changed`
  + local signals; no new signals. **Demo greybox `game/scenes/ui/UISandbox.tscn`** (+ `UISandboxDebug.gd`)
  — a furnished FP room from **real imported assets** (`furniture_quaternius/*.obj` + `props/heist/safe.glb`
  + `characters/Swat.gltf` as the compass "threat" + `Casual.gltf`) with a **real PlayerController** + the
  real HUD, and dev keys driving every readout (J detection · B carry · H go-loud · P pursuit · K damage · N
  noise ring) + opening every menu (O Options · U/I slot popups · Y/L results · M Main Menu). **Deferred (↩
  From 15 → 16, per the user's decision to build 15 against SaveManager's seams):** the menu/slots' **live
  save data** (SlotPopup/MainMenu already call `scan_slots`/`slot_summary`/`save_slot`/`load_slot`/
  `delete_slot`, all stubs → Continue greyed + slots "Empty" on a fresh profile; lights up with no UI edit
  once 16 lands) + the two save-backed integration tests. **Residual (`[~]`):** the M1 human F6 "feel"
  sign-off on `UISandbox.tscn`, mirroring 03–14. The **M1 milestone gate** still needs task 16.
