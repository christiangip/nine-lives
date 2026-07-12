# 08 — Loot & Inventory

**Milestone:** M0 · **Depends on:** 03 · **Blocks:** 11, 14
**Implements:** GDD §10 · **Decisions:** secured-loot banks immediately; multi-trip core.

> **↩ From 05 (AI Actors):** `Body` (`game/systems/ai/Body.gd`) exposes a `concealed` flag +
> `set_concealed()` hook but no drag/carry yet (FR-05-2). Wire body **drag/hide** into the carry
> system here (a body is a heavy two-handed haul), plus the Inspector keycard pickup. Come back
> and tick the body-drag note in `05_ai_actors.md`.
>
> **Closed (2026-07-01):** `Body` now `extends Interactable`; dragging it hands it to the
> carrier's `Inventory` (occupying both hand slots — GDD §10.1's "heavy two-handed haul"),
> conceals it in transit, and grants its `carried_item` (the Inspector's `vault_keycard`) into
> the carrier's held-items set. `set_concealed()` is called on pickup/putdown. Noted in
> `05_ai_actors.md`.

> **↩ From 06 (Obstacles):** obstacle counter-play duck-types the not-yet-built inventory via
> `Obstacle.actor_has_item(by, id)` and a stand-in `PickPouch` (`game/systems/obstacles/PickPouch.gd`).
> Back these with real inventory: **held keycards/keys/clues** (KeycardDoor/Safe/DisplayCase gating),
> **consumable lockpicks** (`Lock` pouch), **data-loot download** into carry (`HackTarget` `data_loot`
> device), and dragging a **knocked-out keyholder** to a `BiometricLock`. Tick the `TODO[08]` hooks
> and the relevant boxes in `06_…md`.
>
> **Closed (2026-07-01):** `PlayerController.has_item()`/`is_carrying_keyholder()` now back
> `Obstacle.actor_has_item()` and `BiometricLock`'s keyholder duck-type for real (both classes
> stayed untouched — the duck-types already called exactly the right shape). Consumable picks
> stay a `PickPouch` handed to any reachable `Lock` by the carrying scene (greybox script here;
> general mission-wide wiring is task 11's). `HackTarget`'s `data_loot` device now resolves
> `def.params.loot_id` and grants that `LootDef` into the hacker's carry. Noted in `06_…md`.

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
> **Implementation note (2026-07-01):** all four phases are code + automated-DoD complete and
> verified green on Godot 4.6.3 (headless GUT **178/178**, +30 task-08 tests). `Inventory`
> (`game/systems/inventory/Inventory.gd`) is a pure-ish `RefCounted` carry brain — weight/volume/
> hand-slot accounting, bagging, body-drag, throwing, and secure/lose bookkeeping — owned by
> `PlayerController`. A carried `Bag` correctly occupies one hand slot (GDD §10.1 lists "gold
> bag" as a hand-slot example), which makes carrying a bag and dragging a `Body` naturally
> mutually exclusive under the 2-slot cap with no special-case code. `DropPoint`/`Escape`
> (`game/systems/inventory/`) expose a pure `secure_from()`/`receive_bag()` banking seam that a
> real `ThrownBag` (`RigidBody3D`) physics landing and a headless GUT test both call identically
> — FR-08-4's throwing is fully unit-tested with zero physics simulation. **EventBus stayed
> frozen** — reuses the four pre-existing loot signals (`loot_picked_up`/`loot_secured`/
> `carry_changed`/`objective_updated`) exactly as declared; everything else (pickup-rejected
> feedback) is a local signal, matching `Obstacle.state_changed`/`Lock.pick_snapped`. **No magic
> numbers:** new carry tunables live on the existing `PlayerConfigDef` (a single directly-
> assigned resource, unlike the Content-registered `*ConfigDef`s); a new `strength.tres`
> `AttributeDef` (`effect_per_level=0.05`, matching `hacking.tres`). `RunManager.add_notoriety`/
> new `add_take()` do real base accumulation now (`TODO[12]`/`TODO[14]` comments mark the
> multiplier/level-up enrichment those tasks still own); `ProgressionManager.add_to_stash()`
> backs FR-08-9's Stash delivery. Dev greybox `game/scenes/inventory/InventoryGreybox.tscn` (+
> `InventoryGreyboxDebug.gd`) composes one loot item per tier/handling style, a `DropPoint`, an
> `Escape`, a `Lock` (pouch-wired), a `BiometricLock`, and a patrolling Inspector guard for
> body-drag/keycard-pickup testing. **Deferred:** Phase 08.4's "HUD secured-vs-remaining
> readout" is real HUD widgetry (task 15) — the debug greybox script surfaces the same data as a
> plain label instead; `LootLedger.is_full_clear(total, secured)` is a one-line pure rule, not a
> live scene tally (that's task 11's `MissionController`, per `ARCHITECTURE.md`).

### Phase 08.1 — Carry model
- [x] Weight + volume accounting vs attribute caps; `can_pick_up()`; `carry_changed` emit.
- [x] Hand-slot handling + movement/agility penalties + vent/climb block.

### Phase 08.2 — Acquisition
- [x] Pickup interaction; bagging flow for loose loot; bag entity.
- [x] Throwing (Strength-gated) with arc + landing-in-Drop-Point detection.

### Phase 08.3 — Banking
- [x] Drop Point + Escape entities; `loot_secured` + value banking into RunManager.
- [x] Secured-loot-survives-Catch persistence; in-hand loss on Catch.

### Phase 08.4 — Special loot & feedback
- [x] Special-hook firing on delivery; HUD secured-vs-remaining readout; full-clear detection.

## Tests (GUT)
- (existing) `test_carry_system.gd` — over-weight and over-volume rejection.
- `test_hand_slot_penalty.gd` — hand-slot loot applies the speed penalty and blocks vents.
- `test_bagging_required.gd` — loose cash can't be carried until bagged.
- `test_secured_survives_catch.gd` — value at a Drop Point persists through a simulated Catch; in-hand value is lost.
- `test_throw_to_drop.gd` — a thrown bag landing in a Drop Point banks its value.
- `test_thrown_bag_settle.gd` — a projectile's landing resolves **exactly once**: two contacts in one frame settle a single `DroppedBag` (not two sharing one `Bag`), a Drop Point banks once, and a reclaimed bag can't be reclaimed twice. *(misc-fixes-4: the missing latch was an infinite-loot duplication loop.)*
- `test_body_drag.gd` — dragging occupies both hand slots, is mutually exclusive with a carried bag, and grants `is_carrying_keyholder()`/held-item duck-types (↩ from 05/06).
- `test_duck_type_bridge.gd` — `Obstacle.actor_has_item()` and `BiometricLock`'s keyholder check resolve through a real `PlayerController`/`Inventory` (↩ from 06).

## Definition of Done
- [x] FR-08-1..9 satisfied; phases checked; tests green. *(Verified on Godot 4.6.3: headless GUT
  **178/178**, `check_docs.sh` clean, and a headless scene-load smoke test of
  `InventoryGreybox.tscn` confirms no missing resources/script errors beyond the same
  headless-dummy-renderer noise `ObstacleGreybox.tscn` already produces.)*
- [~] Manual (M0 playtest): hitting the cap forces a choice; a Drop Point banks value mid-mission; a Catch afterward keeps it. *(Residual — needs an in-editor F6 sign-off on `InventoryGreybox.tscn`, mirroring tasks 03–07: this session verified the scene loads cleanly headlessly but couldn't drive interactive input. Mark `[x]` after a human playtest pass.)*
