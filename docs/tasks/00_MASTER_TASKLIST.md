# 00 — MASTER TASK LIST

The single tracker for building **Nine Lives** from scaffold to playable base game.
Each entry below is a self-contained sub-task-list with its own phases, functional
requirements, tests, and Definition of Done (DoD). Work lists in dependency order;
complete phases **within** a list in order.

**How to read this**
- `[ ]` = not started · `[~]` = in progress · `[x]` = DoD met (all its tests green).
- **M0–M5** = milestone gates (map to GDD §19 roadmap Phases 0–4 + Release).
- "Blocks" = lists that can't meaningfully start until this one's core phases land.

> Decisions locked in `../DESIGN_DECISIONS.md`: first-person · cover-shooter when loud ·
> grounded crime (meta-currency **Legacy**) · 3 currencies · strict saves · no disguises ·
> hybrid procgen. Build against `../ARCHITECTURE.md`.

---

## Milestone gates (the spine)

| Gate | Theme (GDD §19) | Requires lists (core phases) | Proves |
|---|---|---|---|
| **M0** | Prototype / greybox | 01, 02, 03, 04, 05·G, 06·core, 07·core, 08 | The micro-loop is fun |
| **M1** | Roguelite spine | 11·basic, 12, 13·min, 15·menu, 16 | The macro-loop is compelling |
| **M2** | Vertical slice | 11, 06, 07, 09, 10, 14, 15, 17, 18·pass | One shippable-quality slice |
| **M3** | Content & systems breadth | 13, 14, 19, + content in 05/06/09/12 | Depth & replayability |
| **M4** | Polish & live | 20, 21 | Accessible, performant, live-ready |
| **M5** | Release (base game) | all DoD + 21 release phase | **Playable, expandable base game** |

A gate is met only when every required list's DoD is checked **and** the gate's
manual playtest checklist (bottom of this file) is signed off. Tag the commit `mN`.

---

## Dependency overview

```
01 Project Setup ─┬─> 02 Core Architecture ─┬─> 03 Player Controller ─┬─> 04 Stealth/Detection ─> 05 AI Actors
                  │                          │                         └─> 08 Loot & Inventory
                  │                          ├─> 16 Save System ───────────> 15 UI/HUD/Menus
                  │                          └─> (content registries) ─────> 12 Progression
06 Obstacles ─> 07 Minigames                 11 Mission Generation <─ needs 04,05,06,08
09 Gear ─> 10 Going Loud/Pursuit <─ needs 05                         13 Hideout <─ needs 12,16
14 Economy <─ needs 08,12,13     17 Audio <─ needs 04,10     18 Art <─ parallel
19 Expansion <─ needs data-driven 02      20 Milestones/Live <─ needs 12,13,19      21 Release <─ all
```

---

## Sub-task lists

### Foundation
- [x] **01 — Project Setup & Tooling** · `01_project_setup.md` · *(M0)*
  Godot project config, autoload wiring, input map, GUT + CI, config/options persistence. **Blocks: everything.**
  *Complete & **verified on Godot 4.6.3**: headless GUT green + interactive boot → Main Menu smoke. (Local `run_tests.sh`/CI still want `godot` on PATH as the directory, not the `.exe` file.)*
- [x] **02 — Core Architecture & Data Framework** · `02_core_architecture.md` · *(M0)*
  EventBus, manager skeletons, content registries (scan `_defs` instances by id), scene/state machine, base components. **Blocks: 03,11,12,13,16.**
  *Done & **verified green on Godot 4.6.3** (22/22 GUT). Content registries live in a new **10th autoload `Content`**; added a `Services` locator + `SaveManager.migrate()` hook; generic `ContentRegistry` proves "add content without code."*

### Core stealth gameplay (M0)
- [x] **03 — Player Controller & Camera (FP)** · `03_player_controller_camera.md` · *(M0)*
  First-person movement, stances, stamina, lean/peek, interaction raycast, noise emission.
  *Code + automated DoD complete & **verified green on Godot 4.6.3** (GUT 41/41). Data-driven via a new
  `PlayerConfigDef` (+ `default_player.tres`, `stamina`/`silence` attribute defs); local readability signals
  (EventBus stays frozen by its contract test). **In-editor F6 "feel" playtest signed off 2026-06-30**
  after fixing a Godot-3-format `[input]` map that had silently unbound all keyboard/mouse actions.*
- [~] **04 — Stealth & Detection** · `04_stealth_detection.md` · *(M0)*
  Vision cones, light sampling, sound propagation, detection states, noise rings.
  *Code + automated DoD complete & **verified green on Godot 4.6.3** (GUT 64/64). `DetectionSensor`
  fleshed out with pure, deterministic seams (cone/LoS-cover/distance/light/movement/sound) +
  the 5-state machine (Alerted latches; Suspicious/Searching recover); emits the pre-existing
  `detection_changed`/`player_spotted` (EventBus stayed frozen). Tunables in a new
  `DetectionConfigDef` (+ `default_detection.tres`, registered as an 11th `Content` registry);
  per-actor geometry from `EnemyDef` (`default_guard.tres`). **Only residual:** in-editor F6
  "feel" sign-off on `DetectionGreybox.tscn` (then `[x]`).*
- [~] **05 — AI Actors** · `05_ai_actors.md` · *(M0 = Guard only · M2/M3 = full roster + combat)*
  Guards, cameras, operator, dogs, civilians, inspector; state machines over NavigationServer.
  *M0 guard core + Phase 05.2 coordination **code + automated DoD complete & verified green on 4.6.3**
  (GUT 93/93; +6 task-05 tests, incl. a post-review `test_guard_detection_reaction.gd`). Detection
  reactions are **escalate-only** so decay downgrades don't abort an in-progress investigate/search,
  and SEARCH now walks a real sweep ring (`search_radius`). `GuardAI` patrols/investigates/searches/recovers off `DetectionSensor`;
  takedown → discoverable `Body` + `RadioCheckin`; alert propagation. Tunables in a new `AIConfigDef`
  (`Content.ai`); `EnemyDef.scaled()` tiers. **Deferred (↩ noted on the blocking tasks):** 05.3 roster
  (cameras/dogs/civilians/inspector → 06/11), 05.4 combat AI (→ 10), 05.5 perf (→ 11). Residual: F6
  sign-off on `GuardGreybox.tscn`.*
- [~] **06 — Heist Mechanics & Obstacles** · `06_heist_mechanics_obstacles.md` · *(M0 core · M2 full)*
  Locks, safes, keys/keycards, cases, hacking targets, lasers, sensors, biometrics, power, breaching.
  *Obstacle catalogue **code + automated DoD complete & verified green on Godot 4.6.3** (GUT **112/112**,
  +19 task-06 tests). Data-driven via a new `ObstacleDef` (13th `Content` registry `Content.obstacles`,
  16 archetypes); 13 `Interactable` subclasses in `game/systems/obstacles/` with pure seams
  (`snap_chance`/`step_progress`/`can_skip`/`FuseBox.affects` …); EventBus stayed frozen (groups +
  existing `noise_emitted`/`alarm_tripped`). Unblocked the **05 Inspector keycard** (`EnemyDef.carried_item`
  + `inspector.tres` → `vault_keycard` gate). **Deferred with ↩ notes (blocked downstream):** minigame
  overlays → 07, inventory/consumables → 08, gadgets/weapons → 09/10, solution-set consumption + clue
  placement → 11, Intel reveal → 13. **Residual `[~]`:** F6 greybox sign-off (`ObstacleGreybox.tscn`).*
- [~] **07 — Minigames** · `07_minigames.md` · *(M0 core · M2 full)*
  Lockpick, safe-crack, hack, keypad, pickpocket, drill/thermite tension manager.
  *All six frameworks **code + automated DoD complete & verified green on Godot 4.6.3** (GUT **148/148**,
  +36 task-07 tests). `Minigame` base + six subclasses in `game/systems/minigames/` with pure static
  seams under thin overlay glue (keyboard+gamepad via `ui_*`); tunables in a new `MinigameConfigDef`
  (15th `Content` registry `Content.minigames`) + a new `pickpocketing` attribute. A `MinigameHost`
  maps `kind→overlay`, injects difficulty/attribute(TODO[12])/gear(TODO[09]), and routes results back
  via `Obstacle.apply_minigame_result`. Closes the `↩ From 06` overlay slices (EventBus stayed frozen).
  **Deferred (↩ noted):** pickpocket→NPC attach point (civilian roster → 05.3/11). **Residual `[~]`:**
  F6 sign-off on `MinigameGreybox.tscn`.*
- [~] **08 — Loot & Inventory** · `08_loot_inventory.md` · *(M0)*
  Two-axis carry + hand slots, bagging, throwing, Drop Points, Escape, secured-loot-banks rule, multi-trip.
  *Code + automated DoD complete & **verified green on Godot 4.6.3** (GUT **178/178**, +30
  task-08 tests). `Inventory` (`game/systems/inventory/`) is a pure-ish `RefCounted` carry brain
  covering weight/volume/hand-slot caps, bagging, body-drag, throwing, and secure/lose
  bookkeeping (owned by `PlayerController`); `DropPoint`/`Escape` bank through a pure seam a real
  `ThrownBag` physics landing and a headless test both call identically, so FR-08-4's throwing
  is fully unit-tested with zero physics. EventBus stayed frozen (reuses the 4 pre-existing loot
  signals); tunables added to `PlayerConfigDef` + a new `strength` attribute; `RunManager.add_notoriety`/
  new `add_take()` do real base accumulation (`TODO[12]`/`TODO[14]` mark the enrichment layer).
  Closes the task-05 body-drag hook and task-06's `actor_has_item`/keyholder/data-loot duck-types
  **without touching any obstacle code** — `PlayerController` grew the methods those duck-types
  were already calling. Dev greybox `game/scenes/inventory/InventoryGreybox.tscn`. **Residual
  `[~]`:** the in-editor F6 "feel" sign-off, mirroring tasks 04–07 (this session verified the
  scene loads cleanly headlessly but couldn't drive interactive input).*

### Roguelite spine (M1)
- [x] **11 — Mission Generation** · `11_mission_generation.md` · *(M1 basic · M2 full)*
  Prefab sockets, seeded assembler, solvability validation, population, objectives, modifiers, setpieces.
  *Code + automated DoD (M1 **and** M2) **complete & verified green on Godot 4.6.3** (GUT **245/245**, +23
  task-11 tests). Two-stage: `MissionGenerator.generate_layout()` → a pure, seed-reproducible `MissionLayout`
  (assemble → populate), validated headlessly by `MissionValidator` (graph reachability + key/clue fix-point —
  the CI solvability gate); `build()` realizes it into a `MissionController` tree GameManager swaps in. New
  `game/systems/missiongen/`, `SectionDef`+`Contract` schemas, `Content.sections` (18th registry), Bank fully
  authored + Museum/Warehouse. **Closed the ↩ hooks:** Escape→results + reinforcement spawns (10), obstacle
  solvability consumed (06 FR-06-10), MinigameHost.attach_all (07), found-as-loot + loadout-validate (09),
  PlayerController `&"mission_root"` parenting. **Deferred (refreshed ↩):** deep 05.3 AI roster + 05.5 perf;
  real art→18; daily contracts→20; Job Map UI→13/15. **F6 "feel" playtest signed off 2026-07-02**
  (`MissionGreybox.tscn`; that pass added guard cones/colours + a dev loadout/HUD and wired the unused
  `takedown` action). DoD met → `[x]`.*
- [x] **12 — Progression: Streak & Legacy** · `12_progression_streak_legacy.md` · *(M1)*
  Notoriety, Streak Levels, Edges (draw-3), Heat, conversion-on-Catch, permanent Legacy, attributes.
  *Code + automated DoD **complete & verified green on Godot 4.6.3** (headless GUT **270/270**, +25
  task-12 tests). New `ProgressionConfigDef` (**19th registry** `Content.progression`) holds every
  curve. `RunManager` gained the Streak engine as pure static seams (`level_for_notoriety`/
  `stack_multiplier`/`draw_edges`/`heat_multiplier_for`/`convert_to_legacy`): `add_notoriety` applies
  held-Edge multipliers + draws-3 on level-up (`streak_level_up`), a `mission_completed` listener banks
  objective NP × performance multiplier, and `end_streak` converts Notoriety × Heat-mult → Legacy
  (floored) → `add_legacy` → `streak_ended` → reset (FR-12-1..4/9). `ProgressionManager` gained
  Training (`train_attribute` over the `AttributeDef` cost curve + `attribute_effect`) and Legacy Perks
  (`buy_perk`/`can_buy_perk`, prereq-gated). Content: **20 Edges**, **8 Perks**, cost curves on all **14**
  attributes. EventBus stayed frozen. **Closed the `↩ From 10/06/07/08` TODO[12] hooks** (Heat→payout,
  attribute injection into minigames, Lock snap-easing). **Deferred with ↩ notes:** Take-% + Notoriety
  economy tuning → 14; Edge/Perk *effect* wiring into every consuming system → per-system polish.
  **Residual `[~]`:** the M1 "felt" loop needs the Hideout **spend** UI (13) + menu/save (15/16) — that's
  the M1 milestone gate, not task 12 alone.*
- [x] **13 — Hideout & Stations** · `13_hideout_stations.md` · *(M1 min · M3 full)*
  Manifest-driven station system; Job Map, Training, Workshop (min); Armory, Legacy Board, Planning Table, Stash, Fence (full).
  *Code + automated DoD (M1 **and** M3) **complete & verified green on Godot 4.6.3** (headless GUT **295/295**, +25 task-13
  tests). New `game/systems/hideout/HideoutManifest.gd` builds the station list purely from `Content.stations` +
  `ProgressionManager` state (FR-13-1, "add a station with no code" proven by `test_station_manifest`). Manager seams (pure,
  tested): `ProgressionManager` station unlock (`try/can_unlock_station`) + Workshop `research_gear` + Fence
  `convert_stash_item` + `stash_set_bonus_total`; `RunManager` Planning-Table Intel (`buy_intel`/`has_intel`/
  `revealed_modifiers`). A 2D `Hideout.tscn` hub + `StationPanel` base + **8 panels** drive already-tested manager methods,
  plus a 3D furnished `HideoutGreybox.tscn` demo (Phase-1 Quaternius furniture + Casual character; FP walk, `[F]` a prop →
  the same panel; locked props go red→green on unlock). EventBus stayed frozen. **8 `StationDef` + 3 `IntelDef` .tres**
  authored; `LootDef` gained `params` (Stash set bonuses). `GameManager` New Game/Continue land in the Hideout (FR-13-11).
  **Closed the ↩ From 06 (Intel reveal) / 09.1-09.2 (Armory/Workshop/Fence) / 12 (Training/Legacy Board) hooks.** **F6
  "feel" playtest signed off 2026-07-04 → Task 13 complete (`[x]`).** The **M1 milestone gate** still needs 15 (menu/HUD) +
  16 (save) before it's met.*
- [x] **15 — UI/UX, HUD & Menus** · `15_ui_hud_menus.md` · *(M1 menus/HUD · M2 full Options)*
  Main Menu (4 items + Continue-disabled logic), 10-slot popup, full Options, FP-readability HUD.
  *Code + automated DoD **complete & verified green on Godot 4.6.3** (headless GUT **331/331**, +20 task-15
  tests). All UI built in code with a shared `UITheme` (Kenney font + `ui/kit_rpg` textures): **MainMenu**
  (4 items, `continue_enabled()` seam, Exit confirm) → shared **SlotPopup** (NEW/LOAD, `format_slot()` five
  fields / "Empty", Overwrite/Delete confirm); full tabbed **Options** (Graphics/Audio/Controls-remap/
  Accessibility/System) over `SettingsManager` (`DEFAULTS` extended to the §15.2 schema) + `InputManager.
  rebind_action`; the **HUD** (`HUD.gd` + combined **`CompassEye`** detection indicator [fill + directional
  tick, Q1] + carry/objective-secured/pursuit-heat + a loud health/armor/ammo block + on-world
  `NoiseRingSpawner`), mounted by `MissionController.realize()`; **PauseMenu** (Q5 commit messaging) +
  **MissionResults** (Catch/escape payout via `GameManager.pending_results`). EventBus stayed **frozen**.
  Demo greybox **`game/scenes/ui/UISandbox.tscn`** (real Quaternius furniture + safe + Swat/Casual models +
  a real player, dev keys drive every readout + open every menu). **Deferred (↩ From 15 → 16):** the menu/
  slots' **live save data** (SlotPopup/MainMenu already call the SaveManager seams; all "Empty" + Continue
  greyed until 16) + the two save-backed integration tests. **F6 "feel" sign-off passed 2026-07-05:**
  compass-eye fills + points, all readouts live, menus functional, Options persist, Pause Q5 messaging,
  Results screen correct. The **M1 gate** still needs 16.*
- [x] **16 — Save System** · `16_save_system.md` · *(M1)*
  10-slot schema, autosave, `scan_slots()`, load/delete, strict mid-mission policy, migration.
  *Code + automated DoD **complete & verified green on Godot 4.6.3** (headless GUT **343/343**, +12 task-16
  tests). `SaveManager` writes one JSON file per slot under `user://saves/` with **atomic write-then-rename**,
  header validation, and cheap `slot_summary` meta reads; the schema is composed from new `to_dict()/from_dict()`
  seams on `ProgressionManager` (permanent + `playtime_seconds`) and `RunManager` (Streak, folding in the
  `Loadout`/`Contract` serializers + `intel_by_seed`). **Strict integrity (Q5):** a top-level
  `active_mission_committed` checkpoint flag is flipped on-disk the instant an alarm trips
  (`RunManager._on_alarm_tripped` → `SaveManager.mark_committed()`); `load_slot` resolving it runs the hot-quit
  Catch (`end_streak`). **Autosave** at hideout entry / fresh new-game slot / each station spend — between
  missions only. **Migration** bumped `SCHEMA_VERSION → 2` with `_migrate_1_to_2`. MainMenu/`SlotPopup` needed
  **no edits** (closes the `↩ From 15` live-save deferral + its two tests, and the `↩ From 09` loadout↔save DoD
  bullet). Demo `game/scenes/menu/SaveSandbox.tscn`. **F6 sign-off passed 2026-07-05 → Task 16 complete (`[x]`);
  the M1 milestone gate is met.***

### Going loud + breadth (M2/M3)
- [~] **09 — Loadout, Gear & Gadgets** · `09_loadout_gear_gadgets.md` · *(M2)*
  Gear catalog as data, slot rules, consumables/restock, weapons & attachments, armor.
  *Code + automated DoD **complete & verified green on Godot 4.6.3** (GUT **200/200**, +22 task-09
  tests). New `game/systems/loadout/`: `Loadout` (per-slot caps from a new `LoadoutConfigDef` /
  `Content.loadout`, research-gated equip via `ProgressionManager`, consumable `restock()` spending The
  Take, `validate()` + `to_dict/from_dict`), plus pure-ish `Weapon` (ammo/reload/recoil-spread/mods +
  the **suppressed-vs-loud noise seam** feeding 04) and `Armor` (plate absorb/regen + weight→agility)
  models built from `GearDef.params`. 26 `GearDef` `.tres` (no Disguise Kit, Q6). **Closed every
  `↩ From 06` gadget hook** (glasscutter/cloner/spoof via `PlayerController`; stethoscope/hacking-rig
  via `MinigameHost`; drill/thermite/C4 upgrades via new `BreachPoint.equip_tool()`) with zero
  obstacle-consequence changes. EventBus stayed frozen. **Deferred with ↩ From 09 banners:** combat
  firing/damage-routing that consumes `Weapon`/`Armor` → 10; Armory/Fence/Workshop UI → 13; loadout↔save
  → 16; found-as-loot + loadout-into-mission → 11; HUD readout → 15. Residual `[~]`: DoD "round-trips
  through save / feeds 10" (blocked on 16/10).*
- [x] **10 — Going Loud, Combat & Pursuit** · `10_going_loud_pursuit.md` · *(M2)*
  Alarm escalation timeline, cover-shooter (FP cover/lean, weapons, armor, ammo), responder/SWAT tiers, downs/capture, Get-Out-of-Jail.
  *Code + automated DoD **complete & verified green on Godot 4.6.3** (headless GUT **222/222**, +22 task-10
  tests). New `game/systems/pursuit/PursuitDirector.gd` runs phases 0→5 off `EventBus.alarm_tripped` (pure
  seams; a new `PursuitConfigDef` / 17th `Content` registry `Content.pursuit`); `RunManager.raise_heat()` +
  an alarm listener raise Heat + commit the Streak (FR-10-3). New `game/systems/combat/`: `Health` routes
  damage Armor→Health→Downed→Caught with self-revive + the Get-Out-of-Jail check; `PlayerCombat` wraps
  task-09 `Weapon.fire()` in an FP hit-scan. **Closes Phase 05.4:** `GuardAI._tick_combat` holds a standoff
  and fires `EnemyDef.loadout`'s Weapon (new `responder`/`swat`/`specialist_*` `EnemyDef`s). Catch → hands
  off to 12 (`end_streak`) → `goto_results` (FR-10-9). EventBus stayed frozen. **Deferred with ↩ From 10
  banners:** reinforcement spawn placement + `Escape`→results transition → 11; Pursuit/Heat/ammo/health/armor
  HUD → 15; Heat→payout-multiplier + Legacy-conversion formula → 12. **F6 "feel" playtest signed off
  2026-07-02** (going-loud/combat/pursuit verified inside `MissionGreybox.tscn` — L=go-loud, LMB fire,
  reinforcements spawn, damage→Downed→Caught). DoD met → `[x]`.*
- [x] **14 — Economy & Balancing** · `14_economy_balancing.md` · *(M2 wiring · M3 tuning)*
  Three currencies wired, Notoriety multipliers, Take spend (consumables/intel), tuning data tables, balance passes.
  *Code + automated DoD **complete & verified green on Godot 4.6.3** (headless GUT **311/311**, +15 task-14 tests).
  New **`EconomyConfigDef`** (20th `Content` registry `Content.economy`) is the central balance table, authored
  as hot-editable **`data/economy.json`** (loaded via the existing `ContentRegistry` JSON path) — the `↩ From 12`
  handoff. **FR-14-2:** `DropPoint.bank()` splits Notoriety=full / Take=`take_fraction` cut (`add_take` `TODO[14]`
  resolved). **FR-14-3:** RunManager sources the Notoriety multipliers/Heat-slope/floor from `_econ()`;
  `stack_multiplier` relaxed to duck-type the config (task-12 tests stay green). **FR-14-4:** `EconomyValidator`
  range-checks every per-item cost `.tres` + the economy dials (`test_data_tables_valid`, not a rubber stamp).
  **FR-14-6:** `EconomySimulator` (Monte-Carlo, CLEAN vs LOUD, seeded/headless) reports Streak-length + Legacy/run.
  **Stealth-favored tuning (FR-14-5):** clean mean **4.47** contracts / **~35k** Legacy vs loud **1.51** / **~14k**
  → **2.55× ratio**; Intel re-priced to the new Take reality. Also wired the `financier` Perk's
  `legacy_conversion_mult`. Greybox **`EconomyGreybox.tscn`** (FP sandbox, real heist/furniture models, live
  currency header + `[B]` balance readout). EventBus stayed frozen. **Deferred (↩):** Take/Heat HUD → 15;
  economy↔save → 16; balance presets → 20. **F6 "feel" playtest signed off 2026-07-04 → Task 14 complete (`[x]`).***

### Presentation & content (M2/M3)
- [x] **17 — Audio** · `17_audio.md` · *(M2)*
  Dynamic music layers tied to detection/pursuit, diegetic SFX set, 3D positional, bus + Options volumes.
  *Code + automated DoD **complete & verified green on Godot 4.6.3** (headless GUT **356/356**, +13 task-17
  tests). Built on the **frozen EventBus** — `AudioManager` subscribes to the existing globals + exposes a
  local `caption_requested`. **Music:** four looped **procedural placeholder beds** (`AudioStreamWAV`)
  crossfade Calm→Tense→Combat via a pure `music_state_for()` seam + a per-actor detection/pursuit
  aggregator; `mission_completed` → Resolve. **SFX:** cues mapped from the imported **Kenney CC0** set via a
  new **`AudioConfigDef`** (21st registry `Content.audio`); EventBus-global cues handled in AudioManager,
  local-signal sites (Lock snap, BreachPoint drill loop/jam/done, HackTarget/HackMinigame, GuardAI takedown)
  call `play_sfx` directly. **3D positional:** player footsteps off `noise_emitted` + guard cadence
  footsteps. **Buses:** added the missing Ambience bus (Options sliders already wired). **Captions:** HUD
  caption line gated on `audio.subtitles`. Demo `game/scenes/audio/AudioSandbox.tscn`. **M2 manual F6
  sign-off 2026-07-05** (tell calm/tense/combat apart + locate a guard by footsteps); real music stems +
  bespoke SFX noted pending in ART-TODO.*
- [x] **18 — Art & Asset Pipeline** · `18_art_asset_pipeline.md` · *(M2 first pass · ongoing)*
  Sourcing pass, glTF import standards, master materials/palette, manifest/credits/ART-TODO upkeep.
  *First M2 pass **code + automated DoD complete & verified green on Godot 4.6.3** (headless GUT **98/98**,
  +2 art tests; `check_assets.sh` green). New **`Palette`** master-material accessor (`game/systems/art/`) +
  10 `StandardMaterial3D` .tres in `game/assets/materials/`. The dormant art `scene` seam is **wired**:
  `MissionController` realizes `SectionDef.scene` (new `SectionShell` grid-snapped shells — vault + lobby),
  `ObstacleDef.scene` (added; prop prefabs), `LootDef.mesh`, and a new `EnemyDef.model` (real characters +
  a tinted feet-ring so threats stay legible), all additive with a greybox fallback so task-11 tests stay
  green + un-dressed archetypes still build; + a WorldEnvironment/lighting pass tuned for stealth shadows.
  Standalone showcase `bank_test.tscn` recolored to the palette. `check_assets.sh` (manifest-row + LFS gate)
  authored + CI-wired. **Deferred (↩ logged in ART-TODO):** section shells for the other 4 Bank sections +
  Museum/Warehouse; per-tier actor models; loot-model scale pass; grounded prop replacements. **F6
  cohesion/readability sign-off passed 2026-07-05 → task 18 first pass complete (`[x]`).** (Phase 18.4
  upkeep stays ongoing per import; the M2 gate still needs 06/07/09.)*
- [ ] **19 — Expansion Framework** · `19_expansion_framework.md` · *(M3)*
  Hardening the data-driven "add content without code" path; authoring templates; mod-friendly loaders; content validation.

### Live, polish, release (M4/M5)
- [ ] **20 — Progression Milestones & Live Content** · `20_progression_milestones.md` · *(M4)*
  Milestone unlock arcs (stations/gear gated by Legacy/special loot), daily/weekly seeded contracts, rotating modifiers, seasonal goals.
- [ ] **21 — Release, Polish, Accessibility & Performance** · `21_release_polish.md` · *(M4–M5)*
  Accessibility suite, perf budget & profiling, juice, export presets, QA pass, build pipeline.

### Onboarding (woven through M0→M2)
- [ ] **22 — Onboarding & Tutorial** · `22_onboarding_tutorial.md` · *(M1 stub · M2 full)*
  Guided first heist teaching the core verbs in order, then the Streak/Legacy loop. *(Numbered 22 to keep system lists 01–21 contiguous; sequenced after the verbs it teaches exist.)*

---

## Overall progress

```
Foundation        [x01][x02]                        2 / 2
Core stealth (M0) [x03][~04][~05·G][~06][~07][~08]   1 / 6
Spine (M1)        [x11][x12][x13][x15][x16]          5 / 5
Loud + breadth    [~09][x10][x14]                    2 / 3
Presentation      [x17][x18]                        2 / 2
Live + release    [19][20][21]                       0 / 3
Onboarding        [22]                               0 / 1
                                          TOTAL  12 / 22 lists
Milestones        [ ] M0  [x] M1  [ ] M2  [ ] M3  [ ] M4  [ ] M5
```

Update the counts and gate boxes as DoDs are met. The base game ships at **M5**;
content keeps flowing through lists 19–20 thereafter.

---

## Asset coverage by task (art status)

Evaluation of tasks **00–12** against real art assets. **Phase-1 art import
(2026-07-03, `../../phase-1-art.md`)** brought in 8 CC0/CC-BY model kits (720
models) under `game/assets/models/{environment,props}/` with browse galleries in
`game/scenes/art/`. Everything built so far renders as **greybox primitives** in
code; the column below is what real art is *available to wire*, not yet wired.

Legend: ✅ covered by imported assets · ◐ stand-ins available, dedicated art pending ·
⬜ no art yet (later phase) · — no art needed.

| Task | Art it needs | Coverage from phase-1 import |
|---|---|---|
| 00 Master list | — | — |
| 01 Project Setup | — | — |
| 02 Core Architecture | — | — |
| 03 Player Controller (FP) | player body + FP hands | ⬜ pending — Phase 2 (characters) |
| 04 Stealth & Detection | none (cone debug is procedural) | — |
| 05 AI Actors | guard/responder/SWAT/specialist/inspector/civilian + `Body` | ⬜ pending — Phase 2 (characters + Mixamo rig) |
| 06 Obstacles | 17 props (lock, doors, camera, safe, laser, sensors, fuse box, cases, biometrics, breach) | ◐ stand-ins: `server_rack`→`data_server`, `modular_buildings` doors→keycard/keypad leaf, `scifi_megakit` heavy door→vault/breach, `survival/chest`+`factory` box→safe. Dedicated camera/laser/sensors/case/alarm ⬜ Phase 3 |
| 07 Minigames | 2D overlay UI (lockpick arc, dial, node grid, keypad, gauge) | ⬜ pending — Phase 4 (UI kit) |
| 08 Loot & Inventory | loot props (cash, gold, painting, jewelry, data) + duffel bag | ⬜ pending — Phase 3 (loot props) |
| 09 Loadout, Gear & Gadgets | weapons + gadget/tool world models | ⬜ pending — Phase 3 (weapons/gadgets) |
| 10 Going Loud, Combat & Pursuit | weapon viewmodels + responder/SWAT models | ⬜ pending — Phase 2/3 |
| 11 Mission Generation | modular sections + interior/exterior dressing (6 Bank sections, vault setpiece) | ✅ **covered**: `modular_buildings` (walls/doors/windows/floors/steps), `city_commercial` (exterior shells), `factory`+`survival` (loading dock/crates/barrels), `scifi_megakit` (vault/server dressing), `furniture_kenney`+`furniture_quaternius` (office/lobby/teller). Wiring = the `scene`-field seam (phase-1-art step 3) |
| 12 Progression: Streak & Legacy | icons for 20 Edges / 8 Perks / 14 attributes + Hideout UI | ⬜ pending — Phase 4 (icons/UI) |

**Bottom line:** the phase-1 import fully serves **task 11** (sections/environment,
ready to wire) and gives **task 06** a few obstacle stand-ins; tasks 03/05 (characters),
08 (loot), 09/10 (weapons), and 07/12 (UI/icons) await later art phases. **Update (task 18
first pass):** the `scene`-field swap is now **wired** — `MissionController` realizes
`SectionDef.scene` / `ObstacleDef.scene` / `LootDef.mesh` / `EnemyDef.model` (real Bank section
shells, prop prefabs, loot + character models) behind a master-material/palette + lighting pass,
additive with a greybox fallback. Remaining per-section shells, per-tier actors, and grounded prop
replacements are logged in `game/assets/ART-TODO.md`.

---

## Milestone playtest checklists (manual sign-off)

**M0 — Prototype.** In one greybox level: infiltrate; read a guard's cone and slip past it in shadow; pick one lock; hack one panel; take one guard down non-lethally and hide the body; bag loose loot; hit the carry cap and feel the prioritization; ferry a load to a Drop Point and confirm the value **banks** (persists in the HUD readout); make a second trip; extract. Spot-check: getting fully spotted commits the level to alert. *Fun gut-check: was "one more room?" tempting?*

**M1 — Roguelite spine.** ✅ **Signed off 2026-07-05.** From Main Menu: Continue is **greyed out** with no saves; New Game creates a slot, plays the greybox, returns to the Hideout. Complete 2–3 contracts in a Streak (board escalates), trip an alarm (Heat rises), get Caught; confirm Notoriety → **Legacy** payout; spend Legacy on a Training point + a Workshop unlock and feel the difference next Streak; quit and **Continue** restores the slot.

**M2 — Vertical slice.** One polished archetype generated from a seed plays cleanly stealth *or* loud; a vault Crack (keycard → time-lock hack → drill under Pursuit) is completable; going loud triggers the cover-shooter escalation and a sweaty escape; dynamic music tracks the state; full Options apply and persist; no placeholder is *missing* art (ART-TODO may list off-style stand-ins).

**M3 — Breadth.** ≥3 archetypes, ≥6 obstacle types, ≥20 Edges, ≥12 gear items, ≥8 Legacy Perks, all Hideout stations functional, special loot delivers to the Stash with a set bonus, the Take/Intel economy is meaningfully used.

**M4 — Polish & live.** Accessibility options work (colorblind, UI scale, remap, reduce-flashing); 60 FPS held on the target spec in a dense scene; a daily seeded contract loads identically from its seed.

**M5 — Release.** Full playthrough loop is stable across saves/updates (schema migration verified); export builds run on Windows & Linux; CREDITS/manifest complete; no blank assets.
