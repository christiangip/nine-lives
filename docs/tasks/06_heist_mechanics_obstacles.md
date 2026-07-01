# 06 — Heist Mechanics & Obstacles

**Milestone:** M0 (lock/hack/laser core) · M2 (full) · **Depends on:** 02, 03 · **Blocks:** 07, 11
**Implements:** GDD §9.1–9.7 · **Decisions:** Q6 (keycards gate, no disguises).

> **↩ From 05 (AI Actors):** the Inspector roaming gate (FR-05-7, Phase 05.3) needs the
> **must-have keycard** authored here. Once keycards exist, give the Inspector `EnemyDef` a
> carried keycard so taking it down (or pickpocketing) yields the gate key. Come back and
> tick the Inspector item in `05_ai_actors.md`.

## Overview
The puzzle-box catalogue: every obstacle is a data-driven, reusable `Interactable`
with defined counter-play. Obstacles pair with minigames (07) but are never
*only* solvable by a minigame — clues, gadgets, power, and routing are alternates.

## Functional Requirements
- **FR-06-1** Pin-tumbler locks (doors/drawers/chests) → lockpick minigame; picks are consumable and can snap.
- **FR-06-2** Safes → dial-combination minigame; **combo clues** in-level skip/trivialize it; stethoscope widens cues.
- **FR-06-3** Keys & keycards: held by NPCs (pickpocket/takedown) or stashed; keycards **clonable** via gadget; inspector carries a must-have card (05).
- **FR-06-4** Display cases: key/lock, hack, glasscutter (silent), or smash (instant + loud alarm).
- **FR-06-5** Hacking targets: e-locks, keypads, cameras (disable or **loop**), alarm panels, vault time-locks, data loot; hacks need **proximity + time**.
- **FR-06-6** Detection hardware: laser grids, motion sensors, pressure plates, biometric/magnetic locks — each with the GDD counter-play set.
- **FR-06-7** Silent alarms: invisible triggers that summon police; Intel reveals locations.
- **FR-06-8** Power/light: fuse boxes cut power (cameras/locks/lights) with a backup-generator timer + investigate-draw; lights shootable/switchable to expand shadow.
- **FR-06-9** Breaching: drill (timed, jammable, noisy), thermite (timed burn), C4 (instant, max alarm); upgradeable.
- **FR-06-10** Every obstacle exposes its difficulty + valid solution set as data for the generator/Intel.

## Phases
> **Implementation note (2026-07-01):** the obstacle **side** of the whole catalogue is built,
> data-driven (`ObstacleDef` → `Content.obstacles`, 16 archetypes), and unit-tested green (GUT
> **112/112**). Each `game/systems/obstacles/*.gd` extends the base `Interactable` with pure static
> seams. The **downstream halves are deferred** (per the "build what's possible" rule) and carry
> ↩ notes on their blocking docs: skill-minigame overlays → **07**, inventory-backed
> consumables/held cards/gated loot → **08**, gadgets/weapons (glasscutter, stethoscope, EMP, cloner,
> breach charges, light-shoot) → **09/10**, solution-set *consumption* + clue/obstacle placement →
> **11**, Intel reveal → **13**.

### Phase 06.1 — Locks & access (M0 core)
- [x] Pin-tumbler lock interactable + consumable picks + snap rule. *(`Lock.gd` + `PickPouch`; pure
  `snap_chance()`/`should_snap()`, tested. The pick **overlay** is task 07.)*
- [x] Keys/keycards data + door gating; keycard cloner gadget hook. *(`KeycardDoor.gd` +
  `keycard_door.tres`, `required_item` gate + `opens_with()`; cloner + card storage duck-typed → 08/09.)*

### Phase 06.2 — Electronic security (M0 core: one hack target)
- [x] Hack interactable with proximity-lock + time; camera loop vs disable; e-locks; data-loot download.
  *(`HackTarget.gd`: pure `in_proximity()`/`step_progress()` (pause/resume), tested; `device` +
  `camera_action` params; data-loot transfer → 08.)*
- [x] Keypad deduction + found-code alternate. *(`keypad` device + `found_code` clue alternate; the
  Mastermind **deduction overlay** is task 07.)*

### Phase 06.3 — Detection hardware (M0: laser; M2: rest)
- [x] Laser grid + junction-box disable + reveal (Thief Vision/aerosol) + EMP. *(`LaserGrid.gd`:
  `set_powered()` junction/fuse, `reveal()`, `emp()`; aerosol/EMP gadgets → 09, Casing reveal → 08.)*
- [x] Motion sensors, pressure plates, biometric/magnetic locks (+ knocked-out-keyholder route).
  *(`MotionSensor`/`PressurePlate`/`BiometricLock` + pure trip/unlock seams; keyholder-drag → 08.)*
- [x] Silent alarms + Intel reveal. *(`SilentAlarm.gd`: `cross()`→silent alarm, `reveal()` flag; the
  Intel **source** is task 13.)*

### Phase 06.4 — Power, light, breaching (M2)
- [x] Fuse box: zone power-cut, backup generator timer, guard investigate-draw. *(`FuseBox.gd`:
  `cut_power()` + `affects()` zone match + backup timer + `noise_emitted` draw — fully tested.)*
- [x] Light shoot/switch → shadow expansion (feeds 04 light sampling). *(`ControllableLight.gd`:
  switch (silent)/`shoot()` (loud) → `&"shadow"` group; the weapon that shoots it is task 10.)*
- [x] Drill/thermite/C4 breaching with jam/timer/noise; upgrade params. *(`BreachPoint.gd`: pure
  `jam_check()`/`fraction()` + noise; C4 instant-loud; gauge overlay → 07, gear/upgrades → 09.)*

### Phase 06.5 — Safes & cases
- [x] Safe dial obstacle + combo-clue spawning + stethoscope. *(`Safe.gd`: pure `can_skip()` combo
  bypass, tested. Dial + stethoscope **overlay** → 07; physical clue **placement** → 11.)*
- [x] Display case with all four open methods + per-case risk. *(`DisplayCase.gd`: key/hack/
  glasscutter(silent)/smash(loud+alarm); glasscutter gadget → 09.)*

## Tests (GUT)
- `test_lock_snap.gd` — failure can snap a pick; Lockpicking attribute reduces snap odds.
- `test_hack_proximity.gd` — leaving range pauses/fails the hack; returning resumes.
- `test_combo_clue_skip.gd` — possessing the found clue bypasses the safe minigame.
- `test_power_cut.gd` — cutting power disables cameras/e-locks in the zone and starts the generator timer + investigate event.
- `test_solution_set.gd` — each obstacle reports ≥2 valid solutions (never minigame-only) where the GDD requires it.

## Definition of Done
- [~] M0: lock + one hack + laser fully playable with counter-play; tests green. *(All five named
  tests + registry/solution-set green — **112/112**. The **e-lock hack** (timed proximity),
  **laser** (power-cut/junction/EMP/reveal) and **fuse power-cut** are playable now; the **lock**'s
  pick minigame is task 07 (its snap/consume counter-play is done + tested). Residual `[~]`: the
  in-editor **F6 "feel" sign-off** on `game/scenes/obstacles/ObstacleGreybox.tscn`, mirroring 03/04/05.)*
- [~] M2: full catalogue data-driven and consumed by the generator + Intel. *(Catalogue is fully
  data-driven — `ObstacleDef`/`Content.obstacles`, 16 archetypes — and every obstacle **publishes**
  its `difficulty()` + `solution_set()`. **Consumption** by the generator (11) + Intel (13) is
  deferred with ↩ notes; overlays = 07, consumables/gadgets = 08/09/10.)*
