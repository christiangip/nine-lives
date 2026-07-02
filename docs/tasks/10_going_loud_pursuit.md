# 10 — Going Loud, Combat & Pursuit

**Milestone:** M2 · **Depends on:** 05, 09 · **Blocks:** 17
**Implements:** GDD §8.6–8.7 · **Decisions:** **Q2 fuller cover-shooter**.

> **↩ From 05 (AI Actors):** `GuardAI._tick_combat` (state `COMBAT` in
> `game/systems/ai/GuardAI.gd`) is a deferred stub — it only *converges on the last-known
> position* today. **Phase 05.4** (cover selection, suppress/peek, flank, advance under
> Pursuit; responder/SWAT/specialist tiers) lands **here**. Drive it off `EnemyDef.loadout`
> and `AIConfigDef`. Come back and tick 05.4 + DoD-M2 in `05_ai_actors.md` when done.

> **↩ From 06 (Obstacles):** loud obstacle actions already emit the frozen `alarm_tripped("loud")` /
> `noise_emitted` — `DisplayCase.smash`, `BreachPoint` C4, `ControllableLight.shoot`. Wire these into
> the alarm-escalation timeline + Pursuit here, and provide the **firearm** that shoots out a
> `ControllableLight` / camera (`.shoot()`). No new signals needed — the hooks are already on the bus.

> **↩ From 09 (Loadout/Gear):** the `Weapon` and `Armor` MODELS ship in `game/systems/loadout/`
> (built from `GearDef.params`, equipped via the Streak's `RunManager.loadout()`). This task builds the
> **in-world combat** that consumes them: mount a viewmodel that calls `Weapon.fire()` (returns
> damage/spread/noise; it already emits the `noise_emitted` ring, so FR-10-4's Marksmanship-scaled
> spread reads `Weapon.current_spread(marks_effect)`), route damage through `Armor.absorb()` →
> Health for FR-10-6, and consume the `get_out_of_jail` utility for FR-10-7. Come back and tick
> Phase 09.3/09.4's "→ 10" halves + the 09 DoD's second bullet in `09_…md` when combat lands.

## Overview
When stealth breaks, the game becomes a first-person **cover-shooter escape
gauntlet**. Per Q2 this is the fuller model: weapon depth, an armor layer, ammo
economy, and escalating enemy tiers — but you still win by **escaping** with
secured loot, not by holding the building. Raises Heat for the rest of the Streak.

## Functional Requirements
- **FR-10-1** Pursuit timeline phases 0–5 (Calm→Local→Confirmed→Responders→Police flood→Tactical) driven by `EventBus.alarm_tripped` + a response timer; emits `pursuit_phase_changed`.
- **FR-10-2** Silent vs loud alarms both start the timeline; silent alarms can skip ahead without on-screen warning (Intel reveals them).
- **FR-10-3** Going loud ends stealth multipliers and raises Heat (§5.4) for the remainder of the Streak.
- **FR-10-4** FP combat: cover/lean/blindfire, suppression, hit reactions, weapon handling from 09; Marksmanship attribute affects spread/recoil.
- **FR-10-5** Enemy tiers escalate with phase: beat cops → tactical/SWAT → specialists (shield/sniper/breacher); behaviors from 05.4.
- **FR-10-6** Damage → Health then Armor; **Downed** with optional self-revive window; otherwise Down → Caught; **Captured** (surrounded/cuffed) ends the Streak.
- **FR-10-7** **Get-Out-of-Jail** consumable/perk: one-time escape skill-check at capture.
- **FR-10-8** Win condition while loud: reach an Escape with any secured loot; secured value already banked (08) is safe.
- **FR-10-9** On Catch, hand control to 12 for Notoriety→Legacy conversion.

## Phases
### Phase 10.1 — Pursuit director
- [x] Phase state machine + response timers + spawn budget per phase; ~~HUD Heat/Pursuit indicator (15)~~.
  *`PursuitDirector` (`game/systems/pursuit/`) runs phases 0→5 off `EventBus.alarm_tripped` + a response
  timer, re-emitting the frozen `pursuit_phase_changed`; pure seams `start_phase`/`next_phase`/
  `spawn_budget_for`/`tier_for`; tunables in a new `PursuitConfigDef` (17th `Content` registry
  `Content.pursuit`). Reinforcement PLACEMENT **landed with task 11** (`MissionController` wires
  `reinforcements_requested` → spawns the named `EnemyDef`s at reinforce anchors); the HUD indicator → 15.*
- [x] Heat application + ~~future-contract escalation handshake (12/11)~~.
  *`RunManager.raise_heat()` now clamps 0..1 + emits `heat_changed`; an alarm listener sets `committed`
  and raises Heat by the config amount. The Heat→payout-multiplier + future-contract escalation stay
  `TODO[11]/TODO[12]`.*

### Phase 10.2 — Combat core
- [x] FP cover/lean/blindfire; damage model (Health+Armor); hit reactions; downs/self-revive.
  *`Health` (`game/systems/combat/`) routes damage Armor→Health→Downed with a self-revive window
  (pure seams `route_damage`/`is_down`/`skill_check_pass`); `PlayerCombat` viewmodel wraps task-09
  `Weapon.fire()` with a hit-scan + blindfire/suppression spread seams, mounted under `$Head/Hands`.*
- [x] Capture state + Get-Out-of-Jail skill-check.
  *`Health.capture(loadout, skill_input)` runs the one-time Get-Out-of-Jail timing check, consuming the
  consumable on a pass (escape) else latching CAPTURED.*

### Phase 10.3 — Enemy escalation
- [x] Responder/SWAT/specialist tiers + spawn/approach logic (with 05.4).
  *Closes Phase 05.4: `GuardAI._tick_combat` now holds a standoff and fires `EnemyDef.loadout`'s Weapon
  at the player (pure seams `combat_move_intent`/`should_fire`/`is_dead`; `apply_damage` downs the
  guard). New `EnemyDef`s `responder`/`swat`/`specialist_shield`/`specialist_sniper` + an armed base
  guard. Spawn PLACEMENT into a nav-meshed level is deferred to 11 (director computes the budget/tier).*

### Phase 10.4 — Resolution
- [x] Loud-escape win path; Catch → `streak_ended` → 12; results screen handoff (15).
  *Escape banking (task 08) is the loud-escape win (secured value safe by construction). On CAUGHT/
  CAPTURED, `PlayerController` calls `RunManager.end_streak()` (12 owns the Legacy conversion) →
  `GameManager.goto_results()`. The escape-triggers-results scene transition **landed with task 11** —
  `MissionController` listens for `objective_updated("escape", true)` → `GameManager.goto_results`.*

## Tests (GUT)
- `test_pursuit_phases.gd` — alarm advances phases on the timer; silent alarm can jump ahead.
- `test_heat_on_loud.gd` — going loud increments Heat and flags the Streak `committed`.
- `test_damage_down_capture.gd` — damage routes Health→Armor; lethal → Downed → (no revive) Caught; surround → Captured.
- `test_get_out_of_jail.gd` — a successful skill-check escapes capture once; consumed after use.
- `test_secured_safe_on_loud_catch.gd` — a Catch during loud keeps already-secured value.

## Definition of Done
- [x] FR-10-1..9 satisfied; phases checked; tests green.
  *Code + automated DoD complete & **verified green on Godot 4.6.3** (headless GUT **222/222**, +22
  task-10 tests across the 5 named files). EventBus stayed frozen (the pursuit/heat/streak signals
  already existed). FR-10-1..9 met; the remaining cross-task slices (reinforcement PLACEMENT → 11,
  HUD indicators → 15, Heat→payout-multiplier + Legacy-conversion formula → 12) are deferred with
  hooks, not stubbed.*
- [x] M2 manual: an alarm triggers a believable, escalating, survivable-but-scary escape.
  *F6 "feel" **signed off 2026-07-02** — verified inside `game/scenes/mission/MissionGreybox.tscn`
  (the task-11 slice): `L` forces go-loud → phases climb, `LMB` fires the equipped weapon, reinforcements
  spawn at sockets, and damage runs Downed → Caught.*
