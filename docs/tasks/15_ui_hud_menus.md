# 15 — UI/UX, HUD & Menus

**Milestone:** M1 (menus + HUD) · M2 (full Options) · **Depends on:** 16 · **Blocks:** —
**Implements:** GDD §15 · **Decisions:** Q1 (FP-readability HUD), Q5 (commit messaging).

> **↩ From 10 (Going Loud):** the going-loud signal data is live but has no HUD yet — build the
> **Pursuit/Heat indicator** (`EventBus.pursuit_phase_changed` / `heat_changed`) and the loud-combat
> **ammo/health/armor readout** (from `PlayerCombat.active_weapon()` ammo, `PlayerController.health`
> current/max, and `health.armor.current`). Also surface the **Get-Out-of-Jail** timing bar the
> `Health.capture(loadout, skill_input)` check reads. Then tick the HUD notes in `10_going_loud_pursuit.md`.

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

> **↩ To 16 (Save System):** the menu/slot UI is built but its **live data** is task 16 — SlotPopup/MainMenu
> call `SaveManager.scan_slots/slot_summary/save_slot/load_slot/delete_slot`, which are stubs, so Continue is
> greyed + slots read "Empty" until 16 fills them. The two **save-backed** integration tests move to 16 too.
> The pure UI logic (binding, summary formatting, detection→widget, options round-trip) is tested + green here.

## Phases
### Phase 15.1 — Menu & slots (M1)
- [x] Main Menu + Continue-disabled binding + Exit confirm. *(`MainMenu.gd/.tscn`; pure seam
  `MainMenu.continue_enabled(count)`; `ConfirmPopup` on Exit.)*
- [x] 10-slot popup (shared by New Game/Continue) + summaries + Delete confirm. *(`SlotPopup.gd`, NEW/LOAD
  modes; rows render `SaveManager.slot_summary()` via the pure `SlotPopup.format_slot()`; Overwrite/Delete
  confirmed. **Live slot data ↩ From 15 → 16** — all "Empty" until then.)*

### Phase 15.2 — Core HUD (M1)
- [x] Detection indicator + cone-fill + noise ring; carry readout; objective/secured tracker. *(`HUD.gd`
  mounts the combined `CompassEye` (fill + directional tick, Q1), carry W/V + FULL, objective +
  secured/remaining; `NoiseRingSpawner` for the on-world ring. Mounted by `MissionController.realize()`.)*

### Phase 15.3 — Options (M2)
- [x] All Options sections; bind to settings/config; live-apply + persistence; remap UI (with 01).
  *(`Options.gd` TabContainer: Graphics/Audio/Controls-remap/Accessibility/System over `SettingsManager` +
  `InputManager.rebind_action`; `SettingsManager.DEFAULTS` extended to the full §15.2 schema.)*

### Phase 15.4 — Loud HUD & results
- [x] Health/armor/ammo + Pursuit/Heat indicators; Catch/results screen. *(HUD loud block via `loud_visible()`;
  `PauseMenu` with Q5 commit messaging; `MissionResults.gd/.tscn` reads `GameManager.pending_results`.)*

## Tests (GUT)
- [x] `test_continue_enabled_binding.gd` — Continue disabled at 0, enabled at ≥1 (pure seam; the *temp-save*
  half ↩ From 15 → 16).
- [x] `test_slot_popup_summary.gd` — an occupied slot renders the five summary fields; empty renders "Empty."
- [x] `test_options_persist.gd` — changing an option (incl. a new §15.2 key) writes config and survives a reload.
- [x] `test_hud_detection_binding.gd` — `detection_changed` updates the compass-eye indicator/fill; bearing seam.
- [x] `test_ui_scenes.gd` — every new UI surface (menu/HUD/options/slots/pause/results/sandbox) builds in-tree.

## Definition of Done
- [x] FR-15-1..8 satisfied; phases checked; tests green. *(**331/331 green** on Godot 4.6.3. All UI built;
  FR-15-2/3's **live save data** is deferred to 16 — ↩ From 15.)*
- [x] M1 manual: Continue-disabled logic correct; HUD makes FP stealth readable. *(Human F6 sign-off on
  `game/scenes/ui/UISandbox.tscn` passed 2026-07-05 — compass-eye fills + points at threats, carry/
  objective/pursuit/loud readouts live, noise ring visible, all menus open/functional, Options persist,
  Pause Q5 messaging shown, Results screen correct. HUD also renders in `MissionGreybox.tscn`.)*
- **Task 15 complete (`[x]`).** The **M1 milestone gate** still needs task 16 (save system).
