# 04 — Stealth & Detection

**Milestone:** M0 · **Depends on:** 03 · **Blocks:** 05, 11
**Implements:** GDD §8.1–8.3 · **Decisions:** Q1 (FP readability), Pillar 1.

## Overview
The legibility core of the whole game: vision cones, light, sound, and the five
detection states. Everything must be *understandable* — the player should always
know why they were seen or heard. This system is consumed by AI (05), HUD (15),
audio (17), and pursuit (10).

## Functional Requirements
- **FR-04-1** `DetectionSensor` computes per-target detection from LoS (raycast) within a cone (angle+range).
- **FR-04-2** Fill rate scales with distance, light level (shadow shrinks effective range), player stance, player movement, and cover (partial reduces, full blocks).
- **FR-04-3** Five states with the GDD transitions: Unaware→Suspicious→Searching→Alerted→Pursuit, with recovery from Suspicious/Searching.
- **FR-04-4** Sound is a first-class channel: `noise_emitted` events within a guard's hearing radius raise suspicion / draw investigation toward the source position.
- **FR-04-5** Light level is sampled from the environment (lights on/off, shadow volumes) and is modifiable by the player (shoot/switch lights — hook to 06/§9.5).
- **FR-04-6** All detection state is surfaced to the HUD: directional indicator + cone-fill + on-world noise ring (FP readability requirement).
- **FR-04-7** Detection math is deterministic and unit-testable (no hidden randomness in core fill).

## Phases
### Phase 04.1 — Vision
- [ ] Cone test (angle+range) + LoS raycast against occluders.
- [ ] Distance falloff + stance + movement modifiers → fill accumulation.

### Phase 04.2 — Light & cover
- [ ] Light sampling (lit/shadow) shrinks/raises effective range.
- [ ] Cover query: partial (reduce) vs full (block LoS).

### Phase 04.3 — Sound
- [ ] Hearing subscription to `noise_emitted`; distance attenuation; investigate-source behavior handoff to 05.

### Phase 04.4 — State machine & feedback
- [ ] Implement the 5 states + thresholds + recovery timers; emit `detection_changed`, `player_spotted`.
- [ ] HUD feedback hooks: directional eye indicator, cone-fill meter, noise ring.

## Tests (GUT)
- `test_cone_los.gd` — target in-cone + clear LoS detects; behind cover or out-of-cone does not.
- `test_fill_modifiers.gd` — closer/lit/standing/running fills faster than far/shadow/prone/still (ordered assertions).
- `test_state_transitions.gd` — fill thresholds drive Unaware↔Suspicious↔Searching↔Alerted; recovery works.
- `test_sound_investigation.gd` — a noise inside hearing radius flips a guard to Suspicious toward the source.

## Definition of Done
- [ ] FR-04-1..7 satisfied; phases checked; tests green.
- [ ] Manual: a player can read a cone, hug shadow, and recover from Suspicious by breaking LoS.
