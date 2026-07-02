# 13 — Hideout & Stations

**Milestone:** M1 (min: Job Map + Training + Workshop) · M3 (full) · **Depends on:** 12, 16 · **Blocks:** 20
**Implements:** GDD §6 · **Decisions:** Q3 (Legacy Board naming), manifest-driven expandability.

> **↩ From 06 (Obstacles):** the **Intel** reveal half of FR-06-10 / FR-06-7 lands where Intel is
> purchased/previewed (Planning Table). Surface obstacle locations/difficulty/solutions from
> `Content.obstacles`, and reveal otherwise-invisible **silent alarms** via `SilentAlarm.reveal()`.
> Come back and tick DoD-M2 ("consumed by … Intel") in `06_…md`.

> **↩ From 09 (Loadout/Gear):** the `Loadout` brain + gear catalogue (`Content.gear`, 26 `GearDef`)
> exist; this task builds their **station front-ends**. **Armory:** equip/unequip against `Loadout`
> (`can_equip`/`equip`/`validate`, per-slot caps from `Content.loadout`) on the Streak's
> `RunManager.loadout()`. **Workshop:** spend Legacy → append to `ProgressionManager.unlocked_gear`
> (the research gate `Loadout.can_equip` already enforces). **Fence:** call `Loadout.restock(gear, qty)`
> (spends The Take). Come back and tick Phase 09.1/09.2's "→ 13" halves in `09_…md`.

## Overview
The between-mission hub and the safehouse-grows progression arc. Built as
**manifest-driven stations** (`StationDef`): each is a scene + a registry entry, so
new stations ship with **zero core edits** — the central expandability promise.

## Functional Requirements
- **FR-13-1** Hideout scene loads stations from `StationDef` manifest entries (id, scene path, unlock condition, UI hooks); **no central switch**.
- **FR-13-2** Stations lock/unlock by Legacy cost or delivered special loot; locked stations show their unlock requirement.
- **FR-13-3** **Job Map:** diegetic contract select; pins from `RunManager.job_board`; opens a briefing; buying Intel reveals modifiers/manifest.
- **FR-13-4** **Training:** spend Legacy to raise attributes (12).
- **FR-13-5** **Workshop:** research tree unlocking gear/weapon mods/abilities (Legacy); prerequisites.
- **FR-13-6** **Armory:** equip unlocked gear within slot limits; manage consumable loadout (09).
- **FR-13-7** **Legacy Board:** buy permanent Legacy Perks (12).
- **FR-13-8** **Planning Table:** buy Intel with Take/Legacy; review manifests/blueprints/security notes.
- **FR-13-9** **The Stash:** displays delivered special/unique loot; some grant set bonuses (read by 12).
- **FR-13-10** **Fence Terminal:** convert special loot; buy/restock consumables & ammo with Take.
- **FR-13-11** Hideout is the first sight on New Game (post-tutorial) and Continue.

## Phases
### Phase 13.1 — Station framework + min stations (M1)
- [ ] Manifest loader + station mount/unmount + unlock gating + locked-state UI.
- [ ] Job Map (board + briefing + Intel reveal), Training, Workshop (minimum viable).

### Phase 13.2 — Loadout & economy stations (M2)
- [ ] Armory (slot management), Planning Table (Intel), Fence (restock/convert).

### Phase 13.3 — Identity & trophies (M3)
- [ ] Legacy Board (perks), The Stash (trophies + set bonuses), visible safehouse growth.

### Phase 13.4 — Polish
- [ ] Navigation between stations; gamepad support; first-time hints (22).

## Tests (GUT)
- `test_station_manifest.gd` — adding a `StationDef` makes a station appear with **no code change** (mirror of FR-02-5).
- `test_station_unlock.gd` — a locked station unlocks on paying Legacy / delivering the named special loot.
- `test_jobmap_intel.gd` — buying Intel reveals the contract's hidden modifiers/manifest.
- `test_training_spend.gd` — Training spends Legacy and raises the attribute.

## Definition of Done
- [ ] M1: Job Map + Training + Workshop functional; manifest test green.
- [ ] M3: all eight stations functional; safehouse visibly grows with progression.
