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

> **↩ From 12 (Progression):** the Legacy-spend *logic* is built + tested — this task builds the station
> **front-ends** over it. **Training:** `ProgressionManager.train_attribute(attr_id)` (spends the
> `AttributeDef.cost_curve`, raises the level; preview cost via `ProgressionManager.attribute_cost(def, lvl)`)
> over the 14 `Content.attributes`. **Legacy Board:** `ProgressionManager.buy_perk(perk_id)` /
> `can_buy_perk` (prereq + cost gated) over the 8 `Content.perks`. Edges are drawn **in-mission** on
> `EventBus.streak_level_up(level, choices)` → `RunManager.choose_edge(id)` (an in-run overlay, task 15 —
> not a Hideout station). Wiring these station buttons is what makes the **M1 "felt" loop** (the deferred
> DoD bullet in `12_…md`) real — come back and tick it when signing off M1.

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
- [x] Manifest loader (`HideoutManifest`) + station mount/unmount (panel overlay from `StationDef.scene_path`) + unlock gating + locked-state UI.
- [x] Job Map (board + briefing + Intel reveal), Training, Workshop (minimum viable).

### Phase 13.2 — Loadout & economy stations (M2)
- [x] Armory (slot management), Planning Table (Intel), Fence (restock/convert).

### Phase 13.3 — Identity & trophies (M3)
- [x] Legacy Board (perks), The Stash (trophies + set bonuses), visible safehouse growth (locked props → green on unlock in the 3D demo).

### Phase 13.4 — Polish
- [x] Navigation between stations (hub grid ↔ panel overlays, Back / `ui_cancel`); keyboard/gamepad focus. First-time hints deferred → **22** (`TODO[22]`).

## Tests (GUT)
- [x] `test_station_manifest.gd` — adding a `StationDef` makes a station appear with **no code change** (mirror of FR-02-5).
- [x] `test_station_unlock.gd` — a locked station unlocks on paying Legacy / delivering the named special loot.
- [x] `test_jobmap_intel.gd` — buying Intel reveals the contract's hidden modifiers/manifest.
- [x] `test_training_spend.gd` — Training spends Legacy and raises the attribute.
- [x] `test_workshop_research.gd`, `test_fence_convert.gd`, `test_stash_set_bonus.gd` — extra station seams.
- [x] `test_hideout_scenes.gd` (integration) — hub + all 8 panels + the 3D demo instantiate and build in-tree.

## Definition of Done
- [x] M1: Job Map + Training + Workshop functional; manifest test green. *(verified headless GUT 295/295 on Godot 4.6.3)*
- [x] M3: all eight stations functional; safehouse visibly grows with progression. *(code + automated DoD complete)*
- [x] F6 "feel" sign-off on `Hideout.tscn` + `HideoutGreybox.tscn` (interactive) — **signed off 2026-07-04**, mirroring tasks 03–11.

## Progress note
**Code + automated DoD complete & verified green** on Godot 4.6.3 (headless GUT **295/295**, +25 task-13
tests). New `game/systems/hideout/HideoutManifest.gd` builds the station list purely from
`Content.stations` + `ProgressionManager` unlock state — dropping a `StationDef` .tres + a panel scene
adds a station with no code edit (FR-13-1, proven by `test_station_manifest`). **Manager seams (pure,
headless-tested):** `ProgressionManager` gained station unlock (`is/try_unlock_station` +
`can_unlock_station`), Workshop `research_gear` (+ `can_research`), Fence `convert_stash_item`
(+ `convert_value`), and `stash_set_bonus_total` (read by 12); `RunManager` gained the Planning-Table
Intel line (`buy_intel`/`has_intel`/`revealed_modifiers`, per-contract-seed). **UI:** a 2D
`Hideout.tscn` hub (manifest grid, unlock buttons, currency header) + a `StationPanel` base and **8
panels** (`stations/*.tscn`) driving already-tested manager methods; plus a 3D furnished
`HideoutGreybox.tscn` demo (Phase-1 Quaternius furniture + a Casual character, FP walk + `[F]` a prop →
the same panel overlay; locked props show a red placard, turn green on unlock). **EventBus stayed
frozen** (panels use direct manager calls + local `closed`/`loadout_changed` signals). **8 `StationDef`
+ 3 `IntelDef` .tres** authored; `LootDef` gained a `params` field for Stash set bonuses; `IntelDef`
gained `description`/`legacy_cost`. `GameManager` New Game/Continue now land in the Hideout (FR-13-11;
real save I/O still `TODO[16]`). **Closed the deferred hooks:** the `↩ From 06` Intel reveal half
(Planning Table), the `↩ From 09.1/09.2` Armory/Workshop/Fence front-ends, and the `↩ From 12` Training/
Legacy-Board front-ends. **F6 "feel" playtest signed off 2026-07-04** — **Task 13 complete (`[x]`).** The
**M1 milestone gate** itself still needs **15** (menu/HUD) + **16** (save) before it's met.
