# 22 — Onboarding & Tutorial

**Milestone:** M1 (stub) · M2 (full) · **Depends on:** 03, 04, 05, 06, 07, 08 · **Blocks:** —
**Implements:** GDD §17 · **Decisions:** teaches the locked feature set (FP, shadow-stealth).

## Overview
A short, low-stakes guided heist on the first New Game that teaches the core verbs
**in order**, then hands the player to the Hideout and explains the Streak/Legacy
loop. Later mechanics are taught contextually by the contracts that first feature
them — never front-loaded. Sequenced after the verbs it teaches exist (hence #22).

## Functional Requirements
- **FR-22-1** First New Game launches the tutorial heist before the Hideout (GameManager flow).
- **FR-22-2** Teaches, in order: movement & stances → vision cones & shadow → a takedown + hiding a body → a lockpick → a hack → grabbing/bagging loot → using a Drop Point → the carry-limit/multi-trip idea → extraction.
- **FR-22-3** On completion, deposits the player at the Hideout and explains the Streak/Legacy loop + the Job Map.
- **FR-22-4** Contextual teaching: drills, lasers, biometrics, going-loud, and disguise-free restricted-zone keycards are introduced by the first contract that features them (tooltips/beats), not in the intro.
- **FR-22-5** Tutorial is skippable for returning players (per-profile flag) and never blocks Continue.
- **FR-22-6** Tutorial uses the real systems (no bespoke fake mechanics) so lessons transfer.

## Phases
### Phase 22.1 — Flow & stub (M1)
- [ ] First-run detection + GameManager routing into a handcrafted tutorial level; skip flag.
- [ ] Minimal scripted beats for movement/cone/takedown (stub).

### Phase 22.2 — Full guided heist (M2)
- [ ] Full ordered beat list (FR-22-2) with prompts/gating; uses real obstacles/loot/drop.
- [ ] Hideout handoff + Streak/Legacy explanation + Job Map intro.

### Phase 22.3 — Contextual teaching
- [ ] Per-mechanic first-encounter tooltips/beats (drill/laser/biometric/loud/keycard).

## Tests (GUT)
- `test_first_run_routes_tutorial.gd` — a fresh profile boots into the tutorial; a returning profile does not.
- `test_tutorial_skip.gd` — skipping jumps straight to the Hideout without breaking state.
- `test_contextual_trigger.gd` — first encounter with a tagged mechanic fires its teaching beat exactly once.

## Definition of Done
- [ ] FR-22-1..6 satisfied; phases checked; tests green.
- [ ] M2 manual: a new player learns every core verb and can then run the loop unaided.
