# 03 — Player Controller & Camera (First-Person)

**Milestone:** M0 · **Depends on:** 02 · **Blocks:** 04, 08, 10
**Implements:** GDD §8.0 · **Decisions:** Q1 first-person.

## Overview
A responsive first-person controller that the stealth and combat systems read from:
movement, three stances, stamina, lean/peek, and an interaction raycast. Because we
chose FP, the controller is also a *readability surface* — it exposes the data the
HUD needs (stance, noise, lean) so the player can still "see" their stealth state.

## Functional Requirements
- **FR-03-1** Walk/sprint with `CharacterBody3D`; sprint gated by Stamina (attribute-scaled, §5.5).
- **FR-03-2** Stances Stand/Crouch/Prone change collider height, eye height, move speed, and detection profile feed (consumed by 04).
- **FR-03-3** Mouse-look with clamped pitch; sensitivity + invert-Y from settings; gamepad look parity.
- **FR-03-4** Lean/peek left/right (`Q`/`E`) offsets the camera without moving the collider, enabling corner-peeking (FP readability aid).
- **FR-03-5** Interaction raycast detects `Interactable`s, shows their prompt, supports tap & hold.
- **FR-03-6** Movement emits noise via `EventBus.noise_emitted` scaled by stance/speed/surface and the Silence attribute.
- **FR-03-7** Carrying bulky/hand-slot loot applies movement/agility penalties and blocks vents/climb (hooks for 08).

## Phases
### Phase 03.1 — Locomotion
- [x] Capsule body, gravity, walk/sprint, air control, slopes/steps.
- [x] Stamina drain/regen; sprint lockout when empty.

### Phase 03.2 — Stances & camera
- [x] Stand/crouch/prone with smooth collider + eye-height transitions; hold/toggle option.
- [x] FP camera, clamped mouselook, sensitivity/invert from settings, gamepad look.
- [x] Lean/peek with collision-safe camera offset.

### Phase 03.3 — Interaction & noise
- [x] Interaction ray + prompt UI hook + tap/hold timing.
- [x] Surface-tagged footstep noise → `noise_emitted`; Silence attribute scaling.

### Phase 03.4 — Carry hooks
- [x] Expose carry-penalty interface for 08 (speed mult, climb/vent block, viewmodel slot).

## Tests (GUT)
- `test_stamina.gd` — sprint drains; depletion locks sprint; regen restores.
- `test_stance_profile.gd` — each stance yields the expected speed + detection-profile value.
- `test_noise_scaling.gd` — running on metal emits a larger radius than crouch-walking on carpet; Silence shrinks both.
- `test_interaction_ray.gd` — ray reports the nearest interactable and respects hold time.

## Definition of Done
- [x] FR-03-1..7 satisfied; phases checked; tests green.
- [x] Manual: movement feels responsive; peeking a corner reveals a guard without exposing the body.
  *(Verified in-editor via F6 on Godot 4.6.3 after the input-map fix below. GUT 41/41 green.)*
  *(Fixed 2026-06-30: F6 movement/lean/stance were dead because `project.godot [input]` had been
  authored in Godot-3 dict format (`{"type":"key","keycode":N}`), which Godot 4 silently drops →
  all keyboard/mouse actions unbound (only mouse-look, which reads raw motion, worked). Regenerated
  the section in native `Object(InputEventKey,…)` form via `ProjectSettings.save()`; a real W-key
  event now drives the controller. Keyboard playtest is unblocked.)*
