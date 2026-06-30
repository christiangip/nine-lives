# 08 — Loot & Inventory

**Milestone:** M0 · **Depends on:** 03 · **Blocks:** 11, 14
**Implements:** GDD §10 · **Decisions:** secured-loot banks immediately; multi-trip core.

> **↩ From 05 (AI Actors):** `Body` (`game/systems/ai/Body.gd`) exposes a `concealed` flag +
> `set_concealed()` hook but no drag/carry yet (FR-05-2). Wire body **drag/hide** into the carry
> system here (a body is a heavy two-handed haul), plus the Inspector keycard pickup. Come back
> and tick the body-drag note in `05_ai_actors.md`.

## Overview
The economic heartbeat of the micro-loop. A two-axis carry system + hand slots
forces prioritization; physical pickup/bagging/throwing makes carrying the score a
stealth risk; Drop Points bank value **immediately** so partial success always
counts. This is what makes "one more trip?" the central tension.

## Functional Requirements
- **FR-08-1** Two independent caps — Carry Weight (kg) and Carry Volume (L/slots) — from attributes; either being exceeded blocks pickup with a clear "full" signal.
- **FR-08-2** Hand-slot items (1–2) occupy hands, impose movement/agility penalties, and block vents/climb; Strength reduces penalty + enables throwing.
- **FR-08-3** Loot is physically picked up; loose loot (cash/gold) must be **bagged** first; pocketable loot grabbed directly.
- **FR-08-4** Throwing bags (Strength-gated) over gaps/fences/to a Drop Point.
- **FR-08-5** **Drop Points** (infinite capacity) and the **Escape**; reaching either **banks** loot value into Notoriety/Take instantly.
- **FR-08-6** **Secured-loot rule:** banked value persists even if later Caught; loot still *in hand* at a Catch is lost.
- **FR-08-7** Carry state drives 03 penalties and 04 detection (bulky = louder/more visible).
- **FR-08-8** Loot defined by `LootDef` (tier, value, weight, volume, hand slots, needs-bagging, special hook).
- **FR-08-9** Special/unique loot delivery fires a hook (unlock/Stash trophy) consumed by 12/13.

## Phases
### Phase 08.1 — Carry model
- [ ] Weight + volume accounting vs attribute caps; `can_pick_up()`; `carry_changed` emit.
- [ ] Hand-slot handling + movement/agility penalties + vent/climb block.

### Phase 08.2 — Acquisition
- [ ] Pickup interaction; bagging flow for loose loot; bag entity.
- [ ] Throwing (Strength-gated) with arc + landing-in-Drop-Point detection.

### Phase 08.3 — Banking
- [ ] Drop Point + Escape entities; `loot_secured` + value banking into RunManager.
- [ ] Secured-loot-survives-Catch persistence; in-hand loss on Catch.

### Phase 08.4 — Special loot & feedback
- [ ] Special-hook firing on delivery; HUD secured-vs-remaining readout; full-clear detection.

## Tests (GUT)
- (existing) `test_carry_system.gd` — over-weight and over-volume rejection.
- `test_hand_slot_penalty.gd` — hand-slot loot applies the speed penalty and blocks vents.
- `test_bagging_required.gd` — loose cash can't be carried until bagged.
- `test_secured_survives_catch.gd` — value at a Drop Point persists through a simulated Catch; in-hand value is lost.
- `test_throw_to_drop.gd` — a thrown bag landing in a Drop Point banks its value.

## Definition of Done
- [ ] FR-08-1..9 satisfied; phases checked; tests green.
- [ ] Manual (M0 playtest): hitting the cap forces a choice; a Drop Point banks value mid-mission; a Catch afterward keeps it.
