# 09 — Loadout, Gear & Gadgets

**Milestone:** M2 · **Depends on:** 02, 06 · **Blocks:** 10
**Implements:** GDD §11 · **Decisions:** Q2 (weapons/armor), Q6 (no Disguise Kit).

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
- [ ] Author the catalogue as `GearDef` resources; slot rules + Armory validation.
- [ ] Consumable counts + restock economy hook (14).

### Phase 09.2 — Tool/gadget behaviors
- [ ] Wire each tool/gadget to its system (06 obstacles, 04 lasers reveal, etc.).

### Phase 09.3 — Weapons & attachments (Q2)
- [ ] Weapon base (fire, reload, recoil/spread, ammo); attachment/mod system; research gating.
- [ ] Suppressed vs loud noise profiles feeding 04/10.

### Phase 09.4 — Armor (Q2)
- [ ] Armor layer model + regen/repair rules; agility tradeoff; HUD readout (15).

## Tests (GUT)
- `test_slot_limits.gd` — exceeding a slot's capacity is rejected at the Armory.
- `test_consumable_restock.gd` — restocking spends Take and increments counts.
- `test_research_gating.gd` — locked weapons can't be equipped until researched (Legacy).
- `test_weapon_noise_profile.gd` — suppressed shots emit a smaller noise radius than unsuppressed.

## Definition of Done
- [ ] FR-09-1..8 satisfied; phases checked; tests green.
- [ ] Loadout round-trips through save; weapons/armor feed 10 correctly.
