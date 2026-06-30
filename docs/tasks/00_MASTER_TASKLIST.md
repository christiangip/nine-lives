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
- [ ] **04 — Stealth & Detection** · `04_stealth_detection.md` · *(M0)*
  Vision cones, light sampling, sound propagation, detection states, noise rings.
- [ ] **05 — AI Actors** · `05_ai_actors.md` · *(M0 = Guard only · M2/M3 = full roster + combat)*
  Guards, cameras, operator, dogs, civilians, inspector; state machines over NavigationServer.
- [ ] **06 — Heist Mechanics & Obstacles** · `06_heist_mechanics_obstacles.md` · *(M0 core · M2 full)*
  Locks, safes, keys/keycards, cases, hacking targets, lasers, sensors, biometrics, power, breaching.
- [ ] **07 — Minigames** · `07_minigames.md` · *(M0 core · M2 full)*
  Lockpick, safe-crack, hack, keypad, pickpocket, drill/thermite tension manager.
- [ ] **08 — Loot & Inventory** · `08_loot_inventory.md` · *(M0)*
  Two-axis carry + hand slots, bagging, throwing, Drop Points, Escape, secured-loot-banks rule, multi-trip.

### Roguelite spine (M1)
- [ ] **11 — Mission Generation** · `11_mission_generation.md` · *(M1 basic · M2 full)*
  Prefab sockets, seeded assembler, solvability validation, population, objectives, modifiers, setpieces.
- [ ] **12 — Progression: Streak & Legacy** · `12_progression_streak_legacy.md` · *(M1)*
  Notoriety, Streak Levels, Edges (draw-3), Heat, conversion-on-Catch, permanent Legacy, attributes.
- [ ] **13 — Hideout & Stations** · `13_hideout_stations.md` · *(M1 min · M3 full)*
  Manifest-driven station system; Job Map, Training, Workshop (min); Armory, Legacy Board, Planning Table, Stash, Fence (full).
- [ ] **15 — UI/UX, HUD & Menus** · `15_ui_hud_menus.md` · *(M1 menus/HUD · M2 full Options)*
  Main Menu (4 items + Continue-disabled logic), 10-slot popup, full Options, FP-readability HUD.
- [ ] **16 — Save System** · `16_save_system.md` · *(M1)*
  10-slot schema, autosave, `scan_slots()`, load/delete, strict mid-mission policy, migration.

### Going loud + breadth (M2/M3)
- [ ] **09 — Loadout, Gear & Gadgets** · `09_loadout_gear_gadgets.md` · *(M2)*
  Gear catalog as data, slot rules, consumables/restock, weapons & attachments, armor.
- [ ] **10 — Going Loud, Combat & Pursuit** · `10_going_loud_pursuit.md` · *(M2)*
  Alarm escalation timeline, cover-shooter (FP cover/lean, weapons, armor, ammo), responder/SWAT tiers, downs/capture, Get-Out-of-Jail.
- [ ] **14 — Economy & Balancing** · `14_economy_balancing.md` · *(M2 wiring · M3 tuning)*
  Three currencies wired, Notoriety multipliers, Take spend (consumables/intel), tuning data tables, balance passes.

### Presentation & content (M2/M3)
- [ ] **17 — Audio** · `17_audio.md` · *(M2)*
  Dynamic music layers tied to detection/pursuit, diegetic SFX set, 3D positional, bus + Options volumes.
- [ ] **18 — Art & Asset Pipeline** · `18_art_asset_pipeline.md` · *(M2 first pass · ongoing)*
  Sourcing pass, glTF import standards, master materials/palette, manifest/credits/ART-TODO upkeep.
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
Core stealth (M0) [x03][04][05·G][06·c][07·c][08]   1 / 6
Spine (M1)        [11·b][12][13·m][15·m][16]         0 / 5
Loud + breadth    [09][10][14]                       0 / 3
Presentation      [17][18]                           0 / 2
Live + release    [19][20][21]                       0 / 3
Onboarding        [22]                               0 / 1
                                          TOTAL  2 / 22 lists
Milestones        [ ] M0  [ ] M1  [ ] M2  [ ] M3  [ ] M4  [ ] M5
```

Update the counts and gate boxes as DoDs are met. The base game ships at **M5**;
content keeps flowing through lists 19–20 thereafter.

---

## Milestone playtest checklists (manual sign-off)

**M0 — Prototype.** In one greybox level: infiltrate; read a guard's cone and slip past it in shadow; pick one lock; hack one panel; take one guard down non-lethally and hide the body; bag loose loot; hit the carry cap and feel the prioritization; ferry a load to a Drop Point and confirm the value **banks** (persists in the HUD readout); make a second trip; extract. Spot-check: getting fully spotted commits the level to alert. *Fun gut-check: was "one more room?" tempting?*

**M1 — Roguelite spine.** From Main Menu: Continue is **greyed out** with no saves; New Game creates a slot, plays the greybox, returns to the Hideout. Complete 2–3 contracts in a Streak (board escalates), trip an alarm (Heat rises), get Caught; confirm Notoriety → **Legacy** payout; spend Legacy on a Training point + a Workshop unlock and feel the difference next Streak; quit and **Continue** restores the slot.

**M2 — Vertical slice.** One polished archetype generated from a seed plays cleanly stealth *or* loud; a vault Crack (keycard → time-lock hack → drill under Pursuit) is completable; going loud triggers the cover-shooter escalation and a sweaty escape; dynamic music tracks the state; full Options apply and persist; no placeholder is *missing* art (ART-TODO may list off-style stand-ins).

**M3 — Breadth.** ≥3 archetypes, ≥6 obstacle types, ≥20 Edges, ≥12 gear items, ≥8 Legacy Perks, all Hideout stations functional, special loot delivers to the Stash with a set bonus, the Take/Intel economy is meaningfully used.

**M4 — Polish & live.** Accessibility options work (colorblind, UI scale, remap, reduce-flashing); 60 FPS held on the target spec in a dense scene; a daily seeded contract loads identically from its seed.

**M5 — Release.** Full playthrough loop is stable across saves/updates (schema migration verified); export builds run on Windows & Linux; CREDITS/manifest complete; no blank assets.
