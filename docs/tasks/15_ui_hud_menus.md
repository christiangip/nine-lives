# 15 — UI/UX, HUD & Menus

**Milestone:** M1 (menus + HUD) · M2 (full Options) · **Depends on:** 16 · **Blocks:** —
**Implements:** GDD §15 · **Decisions:** Q1 (FP-readability HUD), Q5 (commit messaging).

## Overview
The player's contract with the game. Two big jobs: the **menu/slot system** (incl.
the Continue-disabled logic) and the **in-mission HUD** that keeps first-person
stealth legible (the FP readability requirement from Q1).

## Functional Requirements
- **FR-15-1** Main Menu has exactly four items: New Game, Continue, Options, Exit (with confirm).
- **FR-15-2** **Continue is greyed out when no save exists**, bound to `SaveManager.populated_count() > 0`, re-checked on menu load.
- **FR-15-3** 10-slot popup: occupied slots show Streak length, total Legacy, playtime, last-played date, last contract; empty read "Empty." Reused by New Game (choose/overwrite, with confirm) and Continue (load). Per-slot Delete with confirm.
- **FR-15-4** Full Options (Graphics/Audio/Controls/Gameplay-Accessibility/System) per GDD §15.2; persisted via `ConfigFile`; live-apply where possible.
- **FR-15-5** **HUD:** directional detection indicator + cone-fill (the "eye"), on-world noise ring, carry readout (W/V vs caps + full warning), objective tracker + secured-vs-remaining value, Pursuit/Heat indicator, health/armor/ammo when loud.
- **FR-15-6** Minigames render as focused diegetic overlays (07).
- **FR-15-7** HUD is minimal, trustable, and accessibility-aware (no color-only cues; UI scale).
- **FR-15-8** Results/Catch screen summarizes the mission/Streak and the Legacy payout.

## Phases
### Phase 15.1 — Menu & slots (M1)
- [ ] Main Menu + Continue-disabled binding + Exit confirm.
- [ ] 10-slot popup (shared by New Game/Continue) + summaries + Delete confirm.

### Phase 15.2 — Core HUD (M1)
- [ ] Detection indicator + cone-fill + noise ring; carry readout; objective/secured tracker.

### Phase 15.3 — Options (M2)
- [ ] All Options sections; bind to settings/config; live-apply + persistence; remap UI (with 01).

### Phase 15.4 — Loud HUD & results
- [ ] Health/armor/ammo + Pursuit/Heat indicators; Catch/results screen.

## Tests (GUT)
- `test_continue_enabled_binding.gd` — Continue disabled at 0 saves, enabled at ≥1 (with a temp save).
- `test_slot_popup_summary.gd` — an occupied slot renders the five summary fields; empty renders "Empty."
- `test_options_persist.gd` — changing an option writes config and survives a reload.
- `test_hud_detection_binding.gd` — `detection_changed` updates the indicator/cone-fill.

## Definition of Done
- [ ] FR-15-1..8 satisfied; phases checked; tests green.
- [ ] M1 manual: Continue-disabled logic correct; HUD makes FP stealth readable.
