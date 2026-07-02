# 09 — Loadout, Gear & Gadgets

**Milestone:** M2 · **Depends on:** 02, 06 · **Blocks:** 10
**Implements:** GDD §11 · **Decisions:** Q2 (weapons/armor), Q6 (no Disguise Kit).

> **↩ From 06 (Obstacles):** obstacles expose gadget hooks that currently duck-type to `false` —
> supply them as `GearDef`: **keycard cloner** (`KeycardDoor._can_clone`), **glasscutter**
> (`DisplayCase.cut`), **biometric spoof** (`BiometricLock`), **EMP + aerosol** (`LaserGrid.emp/reveal`),
> **stethoscope** (widens the safe-dial cue), and **breach charges** (drill/thermite/C4 `params` +
> upgrades on `BreachPoint`). Come back and tick the `TODO[09]` hooks in `06_…md`.

## Overview
Gear is data (`GearDef`): unlocked permanently via Workshop research (Legacy),
equipped at the Armory within slot limits, consumables restocked with The Take.
Q2 expands the weapon/armor side into a real cover-shooter loadout; Q6 removes the
Disguise Kit.

## Functional Requirements
- **FR-09-1** Slots: Tool / Breach / Gadget / Weapon / Utility / Apparel with per-slot capacity limits enforced at the Armory.
- **FR-09-2** Tools/gadgets from the catalogue (lockpick set/gun, hacking rig, stethoscope, glasscutter, keycard cloner, casing visor, EMP, smoke, noisemaker, aerosol, throwables) with tiered params.
- **FR-09-3** Breaching gear (drill/thermite/C4) with upgrade params consumed by 06.
- **FR-09-4** **Weapons (Q2):** suppressed pistol, sedative dart gun, SMG, rifle, shotgun + attachments/mods; ammo types; researched at Workshop.
- **FR-09-5** **Armor (Q2):** plate/segment layer on top of Health; weight/agility tradeoff.
- **FR-09-6** Consumables track count; restock via Take at Fence; some found as loot.
- **FR-09-7** No Disguise Kit (Q6); soft-soled gear (Silence) retained.
- **FR-09-8** Loadout is validated pre-mission and serialized into the Streak/save.

## Phases
### Phase 09.1 — Gear data & slots
- [x] Author the catalogue as `GearDef` resources; slot rules + Armory validation. *(26 `GearDef`
  `.tres` in `game/resources/gear/`; `Loadout` enforces per-slot capacity from `LoadoutConfigDef`
  (`Content.loadout`) + `validate()`. **Armory station UI → 13.**)*
- [x] Consumable counts + restock economy hook (14). *(`Loadout.restock()` spends `RunManager.take`
  per unit, capped at `GearDef.max_count`; pure `can_restock()` seam. **Fence UI + Take-scaling → 13/14.**)*

### Phase 09.2 — Tool/gadget behaviors
- [x] Wire each tool/gadget to its system (06 obstacles, 04 lasers reveal, etc.). *(Closes the
  `↩ From 06` gadget hooks: `PlayerController.has_glasscutter()/can_clone_keycard()/has_biometric_spoof()`
  answer from the loadout; `MinigameHost._gear_params()` feeds `stethoscope`/`hacking_rig` +
  the breach tool's method/upgrades; soft-soled gear's Silence bonus folds into footstep noise;
  `LaserGrid.emp()/reveal()` seams exist for EMP/aerosol. **In-world active-throw of EMP/aerosol/smoke
  → 10/11 population.**)*

### Phase 09.3 — Weapons & attachments (Q2)
- [x] Weapon base (fire, reload, recoil/spread, ammo); attachment/mod system; research gating.
  *(`Weapon` model built from `GearDef.params`: ammo/reload, recoil-driven spread, `attach()` mods;
  `Loadout.can_equip` gates on `ProgressionManager` unlock. **In-world firing/hit-resolution/cover → 10.**)*
- [x] Suppressed vs loud noise profiles feeding 04/10. *(pure `Weapon.shot_noise_radius()`; `fire()`
  emits the frozen `EventBus.noise_emitted("gunshot")` so detection reacts pre-combat.)*

### Phase 09.4 — Armor (Q2)
- [x] Armor layer model + regen/repair rules; agility tradeoff; HUD readout (15). *(`Armor` model:
  `split()`/`absorb()` overflow-to-Health, post-hit-delay regen, weight→`agility_mult()`.
  **Damage routing/Downed → 10; HUD readout → 15.**)*

## Tests (GUT) — all green on Godot 4.6.3 (suite 200/200)
- [x] `test_slot_limits.gd` — exceeding a slot's capacity is rejected at the Armory.
- [x] `test_consumable_restock.gd` — restocking spends Take and increments counts.
- [x] `test_research_gating.gd` — locked weapons can't be equipped until researched (Legacy).
- [x] `test_weapon_noise_profile.gd` — suppressed shots emit a smaller noise radius than unsuppressed.
- [x] extras: `test_armor_layer.gd`, `test_loadout_gear.gd` (serialize + gadget flags), `test_breach_gear.gd`.

## Definition of Done
- [x] FR-09-1..8 satisfied; phases checked; tests green. *(The 09-owned data + models + validation are
  complete and unit-tested; downstream halves are deferred with `↩ From 09` banners — see Progress.)*
- [~] Loadout round-trips through save; weapons/armor feed 10 correctly. *(Serialization
  `to_dict()/from_dict()` round-trips and is tested; wiring it into `SaveManager` is **task 16**, and
  the cover-shooter that consumes the `Weapon`/`Armor` models is **task 10**.)*

## Progress
**09 — Loadout, Gear & Gadgets:** code + automated DoD **complete & verified green on Godot 4.6.3**
(headless GUT **200/200**, +22 task-09 tests). New domain `game/systems/loadout/` — `Loadout`
(`RefCounted`, owned by `RunManager`, read by `PlayerController`): per-slot capacity from a new
**`LoadoutConfigDef`** (16th `Content` registry `Content.loadout`), research-gated equip
(`ProgressionManager` unlocks), consumable counts + `restock()` spending The Take, `gear_flags()` for
the MinigameHost, `validate()` + `to_dict()/from_dict()` (FR-09-8). `Weapon` + `Armor` are pure-ish
models built from `GearDef.params` (extended with `tier`/`slot_cost`/`max_count`): weapon
ammo/reload/recoil-spread/attachments + the **suppressed-vs-loud noise seam** (feeds 04 via the frozen
`noise_emitted`), and the armor plate/overflow/regen + weight→agility layer. 26 `GearDef` `.tres`
authored (tools, breach drill/thermite/C4, gadgets, weapons, suppressor mod, utility, apparel — **no
Disguise Kit**, Q6; soft-soled gear retains Silence). **EventBus stayed frozen** (loadout changes are a
local `loadout_changed`; gunshots reuse `noise_emitted`). Added a `marksmanship` attribute.
**Closed every `↩ From 06` gadget hook without touching obstacle *consequence* code:** glasscutter/
cloner/biometric-spoof via `PlayerController` loadout queries, stethoscope/hacking-rig via
`MinigameHost._gear_params()`, and the drill/thermite/C4 **breach upgrades** via a new additive
`BreachPoint.equip_tool()` (identity when no gear → the 112 task-06 tests are unchanged). **Deferred
(↩ banners added to the blocking docs):** cover-shooter firing/damage-routing/Downed + the alarm
timeline consuming these models → **10**; Armory/Fence/Workshop station UI + restock/research screens →
**13**; loadout↔`SaveManager` serialization → **16**; found-as-loot + loadout-into-mission + active-
throw gadgets → **11**; armor/ammo HUD readout → **15**.
