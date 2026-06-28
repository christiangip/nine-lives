# 07 — Minigames

**Milestone:** M0 (lockpick + hack) · M2 (full set) · **Depends on:** 02, 06 · **Blocks:** —
**Implements:** GDD §9.8 · **Decisions:** scaled by attribute/gear; FP diegetic close-ups.

## Overview
A small set of standardized, reusable minigame frameworks subclassing `Minigame`.
Each scales by the relevant attribute + gear, snaps to a focused diegetic overlay,
and is skippable via clues/intel where sensible. Never the *only* solution.

## Functional Requirements
- **FR-07-1** All minigames extend `Minigame` and emit `solved` / `failed(reason)` / `aborted`.
- **FR-07-2** Difficulty parameterizes each (tiers from the obstacle/contract); attribute + gear widen tolerances/speed.
- **FR-07-3** **Lockpick:** rotate to a sweet-spot arc; tension opens the pin; missing risks a snap; Lockpicking widens arc + reduces snaps.
- **FR-07-4** **Safe-crack:** chain dial clicks at correct numbers (audio+subtle visual cue); more wheels/tighter tolerance at tiers; stethoscope widens cues.
- **FR-07-5** **Hack:** node-routing/sequence under a soft timer with proximity-lock; Hacking adds fault tolerance; distinct visual variants per target type.
- **FR-07-6** **Keypad:** Mastermind-style deduction; Pickpocketing/Hacking unrelated; supports found-code instant solve.
- **FR-07-7** **Pickpocket:** moving timing meter; stop in the safe zone; window scales with Pickpocketing; failure nudges NPC suspicious.
- **FR-07-8** **Drill/Thermite:** not a puzzle — a tension manager: progress timer, jam events needing a repair interaction, continuous noise emission.
- **FR-07-9** Each minigame is keyboard+gamepad playable and accessibility-aware (no reliance on color/audio alone).

## Phases
### Phase 07.1 — Framework (M0)
- [ ] `Minigame` lifecycle, overlay mount/unmount, pause-world handling, abort path.
- [ ] Attribute+gear injection API; difficulty mapping helper.

### Phase 07.2 — Lockpick + Hack (M0)
- [ ] Lockpick arc/tension/snap; juice + SFX hooks (17).
- [ ] Hack node-routing + soft timer + proximity-lock; one visual variant.

### Phase 07.3 — Safe + Keypad (M2)
- [ ] Safe dial clicks + wheels + stethoscope; combo-clue instant-solve path.
- [ ] Keypad deduction + found-code path.

### Phase 07.4 — Pickpocket + Drill/Thermite (M2)
- [ ] Pickpocket timing meter + suspicion-on-fail.
- [ ] Drill/thermite tension manager + jam/repair + noise.

## Tests (GUT)
- `test_minigame_lifecycle.gd` — begin→solve/fail/abort emit correct signals once.
- `test_lockpick_scaling.gd` — higher Lockpicking widens the sweet-spot and lowers snap probability.
- `test_hack_timer_proximity.gd` — running out of soft time fails; leaving proximity pauses.
- `test_keypad_deduction.gd` — correct deduction sequence solves; found-code path instant-solves.
- `test_pickpocket_window.gd` — Pickpocketing widens the safe-zone window.

## Definition of Done
- [ ] M0: lockpick + hack fully playable and attribute-scaled; tests green.
- [ ] M2: all six frameworks shipped, accessible, and wired to obstacles (06).
