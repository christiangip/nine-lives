# 05 — AI Actors

**Milestone:** M0 (Guard only) · M2/M3 (full roster + combat) · **Depends on:** 04 · **Blocks:** 10, 11
**Implements:** GDD §8.4 · **Decisions:** Q2 (combat behaviors), Q6 (Inspector reworked).

> **↩ From 07 (Minigames):** the pickpocket **framework** is built (`PickpocketMinigame` — a timing
> meter whose safe zone widens with the `pickpocketing` attribute) but has **no NPC to lift from yet**.
> When civilians land (FR-05-6), make a pickpockable civilian an `Obstacle`-style requester: emit
> `minigame_requested(&"pickpocket")`, override `apply_minigame_result(&"pickpocket", success)` to yield
> a key/keycard on success, and react to the overlay's `failed("caught")` by nudging suspicion. Then come
> back and tick "Pickpocket timing meter + suspicion-on-fail" in `07_minigames.md`.

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
- [x] Nav patrol over waypoints; idle/look-around. *(`GuardAI` direct-steers a looping waypoint
  route with a `waypoint_pause` glance; NavigationServer pathing for obstacle avoidance is a later
  refinement — open-floor greybox needs no nav-mesh bake.)*
- [x] Investigate (go to last-known position) ↔ Search (local sweep) ↔ resume, tied to 04 states.
  *(Detection reactions are **escalate-only**: a rising meter promotes the guard, but decay-driven
  downgrades don't interrupt an in-progress investigate/search — those wind down on their own
  timers, so the loop actually completes. Non-combat leads route through INVESTIGATE first (walk to
  the contact) so SEARCH sweeps a real ring of points around it (`search_radius`), not in place.
  Covered by `test_guard_detection_reaction.gd`.)*
- [x] Takedown reaction; body spawn; discovery → alarm. *(`take_down()` → `Body` (group `&"body"`)
  + armed `RadioCheckin`; guards scan their cone for un-concealed bodies → `body_discovered`/`alarm_tripped`.)*
  **Drag/hide DONE in 08 (2026-07-01):** `Body` now `extends Interactable` (a runtime-spawned
  `_spawn_body()` body gets a procedural collider + placeholder mesh so it's actually
  raycastable); dragging it hands it to the carrier's `Inventory` (both hand slots, per GDD
  §10.1's "heavy two-handed haul"), grants its `carried_item` (the Inspector's `vault_keycard`),
  and `set_concealed()` toggles on pickup/putdown — closing FR-05-2's drag/hide half.

### Phase 05.2 — Radios & coordination
- [x] Radio check-in fakeable-count escalation. *(`RadioCheckin.try_fake()`; the on-screen
  hold-prompt **widget** is HUD task 15 — logic + hook shipped here.)*
- [x] Nearby-guard alert propagation on Searching/Alerted. *(`GuardAI` converges to investigate
  on a teammate's spot/search/body-find within `alert_propagation_radius`.)*

### Phase 05.3 — Sensors-as-actors  *(deferred — needs mission population/keycards/inventory)*
- [ ] Camera arc + monitoring feed / delayed auto-alarm; operator blind-window. *(↩ build in 11.)*
- [ ] Guard dog scent sensor; civilian panic FSM; inspector roaming + keycard carry.
  *(**Inspector keycard-carry DONE in 06 (2026-07-01):** `EnemyDef.carried_item` added +
  `resources/enemies/inspector.tres` carries `&"vault_keycard"`, which gates `keycard_door.tres` —
  taking the Inspector down / pickpocketing yields the gate key (FR-05-7). Still pending: the
  **roaming** behavior + dog scent + civilian panic FSM (↩ population on 11). `EnemyDef.Kind` enumerates all.)*

### Phase 05.4 — Combat AI (M2, with 10)  *(deferred — hard-blocked by task 10)*
- [ ] Cover selection, suppress/peek, flank, advance under Pursuit; responder/SWAT/specialist tiers.
  *(↩ `GuardAI._tick_combat` is a converge-only stub; flesh out in `10_going_loud_pursuit.md`.)*

### Phase 05.5 — Performance  *(deferred — profile against 11's dense populations)*
- [ ] Round-robin AI ticks; sleep distant actors; budget for 60 FPS with dense populations.

## Tests (GUT) — **all green on Godot 4.6.3** (seam-style, headless-deterministic)
- `test_guard_patrol.gd` — guard follows waypoints and loops.
- `test_investigate_recover.gd` — noise → investigate last position → return to patrol if nothing found.
- `test_body_discovery_alarm.gd` — an unhidden body within a cone raises the alarm; hidden does not.
- `test_radio_checkin.gd` — exceeding the fakeable-checkin count escalates to alarm.
- `test_enemydef_scaling.gd` — higher-tier `EnemyDef` yields larger cones/health/speed.
- `test_guard_detection_reaction.gd` — *(added post-review)* the live `_on_detection_changed`
  path: SEARCH/INVESTIGATE survive decay downgrades; escalation still promotes; combat latches.

## Definition of Done
- [~] M0: Phase 05.1 done + its tests green (guard usable in the greybox). *(Code + automated DoD
  complete & **verified green on 4.6.3**; only residual is the in-editor F6 "feel" sign-off on
  `game/scenes/ai/GuardGreybox.tscn` — mark `[x]` after it, mirroring tasks 03/04.)*
- [ ] M2/M3: 05.2 done; 05.3–05.5 deferred (see per-phase ↩ notes); combat AI integrates with 10; perf budget held.
