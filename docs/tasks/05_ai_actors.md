# 05 — AI Actors

**Milestone:** M0 (Guard only) · M2/M3 (full roster + combat) · **Depends on:** 04 · **Blocks:** 10, 11
**Implements:** GDD §8.4 · **Decisions:** Q2 (combat behaviors), Q6 (Inspector reworked).

## Overview
Rule-driven, readable AI as lightweight state machines over `NavigationServer3D`.
Fairness over emergent chaos. Guards are the M0 vertical; the rest of the roster
(cameras, operator, dogs, civilians, inspector, responders) lands across M2–M3.

## Functional Requirements
- **FR-05-1** `GuardAI` patrols (fixed/wandering routes), investigates noises/sightings, searches on finding evidence, and resumes — driven by `DetectionSensor` (04).
- **FR-05-2** Guards can be taken down (non-lethal/lethal); a downed/dead body is discoverable and raises alarm; bodies can be dragged/hidden (hook to 08/§8.5).
- **FR-05-3** **Radio check-ins:** after a takedown a guard's radio may demand a check-in; a limited number are fakeable before HQ escalates.
- **FR-05-4** Cameras sweep arcs feeding a monitoring room (or a delayed auto-alarm); the operator can be removed to blind feeds for a window.
- **FR-05-5** Guard dogs detect by scent radius (ignores LoS/shadow); countered by lures/avoidance.
- **FR-05-6** Civilians panic on sight and can trip/raise alarms; can be avoided or non-lethally subdued; (loud) intimidated.
- **FR-05-7** Inspector (Q6 rework): roams restricted zones unpredictably and **carries a must-have keycard**; no disguise-detection role.
- **FR-05-8** Combat behaviors (Q2): on Pursuit, combatants take cover, suppress, flank, and reposition (detailed tuning in 10).
- **FR-05-9** All actor params come from `EnemyDef` (data-driven); difficulty tiers scale them.

## Phases
### Phase 05.1 — Guard core (M0)
- [ ] Nav patrol over waypoints; idle/look-around.
- [ ] Investigate (go to last-known position) ↔ Search (local sweep) ↔ resume, tied to 04 states.
- [ ] Takedown reaction; body spawn; discovery → alarm.

### Phase 05.2 — Radios & coordination
- [ ] Radio check-in prompt + fakeable-count escalation.
- [ ] Nearby-guard alert propagation on Searching/Alerted.

### Phase 05.3 — Sensors-as-actors
- [ ] Camera arc + monitoring feed / delayed auto-alarm; operator blind-window.
- [ ] Guard dog scent sensor; civilian panic FSM; inspector roaming + keycard carry.

### Phase 05.4 — Combat AI (M2, with 10)
- [ ] Cover selection, suppress/peek, flank, advance under Pursuit; responder/SWAT/specialist tiers.

### Phase 05.5 — Performance
- [ ] Round-robin AI ticks; sleep distant actors; budget for 60 FPS with dense populations.

## Tests (GUT)
- `test_guard_patrol.gd` — guard follows waypoints and loops.
- `test_investigate_recover.gd` — noise → investigate last position → return to patrol if nothing found.
- `test_body_discovery_alarm.gd` — an unhidden body within a cone raises the alarm; hidden does not.
- `test_radio_checkin.gd` — exceeding the fakeable-checkin count escalates to alarm.
- `test_enemydef_scaling.gd` — higher-tier `EnemyDef` yields larger cones/health/speed.

## Definition of Done
- [ ] M0: Phase 05.1 done + its tests green (guard usable in the greybox).
- [ ] M2/M3: 05.2–05.5 done; combat AI integrates with 10; perf budget held.
