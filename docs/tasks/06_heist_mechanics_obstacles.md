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
### Phase 06.1 — Locks & access (M0 core)
- [ ] Pin-tumbler lock interactable + consumable picks + snap rule.
- [ ] Keys/keycards data + door gating; keycard cloner gadget hook.

### Phase 06.2 — Electronic security (M0 core: one hack target)
- [ ] Hack interactable with proximity-lock + time; camera loop vs disable; e-locks; data-loot download.
- [ ] Keypad deduction + found-code alternate.

### Phase 06.3 — Detection hardware (M0: laser; M2: rest)
- [ ] Laser grid + junction-box disable + reveal (Thief Vision/aerosol) + EMP.
- [ ] Motion sensors, pressure plates, biometric/magnetic locks (+ knocked-out-keyholder route).
- [ ] Silent alarms + Intel reveal.

### Phase 06.4 — Power, light, breaching (M2)
- [ ] Fuse box: zone power-cut, backup generator timer, guard investigate-draw.
- [ ] Light shoot/switch → shadow expansion (feeds 04 light sampling).
- [ ] Drill/thermite/C4 breaching with jam/timer/noise; upgrade params.

### Phase 06.5 — Safes & cases
- [ ] Safe dial obstacle + combo-clue spawning + stethoscope.
- [ ] Display case with all four open methods + per-case risk.

## Tests (GUT)
- `test_lock_snap.gd` — failure can snap a pick; Lockpicking attribute reduces snap odds.
- `test_hack_proximity.gd` — leaving range pauses/fails the hack; returning resumes.
- `test_combo_clue_skip.gd` — possessing the found clue bypasses the safe minigame.
- `test_power_cut.gd` — cutting power disables cameras/e-locks in the zone and starts the generator timer + investigate event.
- `test_solution_set.gd` — each obstacle reports ≥2 valid solutions (never minigame-only) where the GDD requires it.

## Definition of Done
- [ ] M0: lock + one hack + laser fully playable with counter-play; tests green.
- [ ] M2: full catalogue data-driven and consumed by the generator + Intel.
