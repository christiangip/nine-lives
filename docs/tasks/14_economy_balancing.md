# 14 — Economy & Balancing

> **↩ From 12 (Progression) — CLOSED:** task 12 shipped the currency *plumbing*; task 14 wired + tuned it.
> (1) `RunManager.add_take()` `TODO[14]` resolved — `DropPoint.bank()` now banks Notoriety=full but
> Take=`take_fraction` cut (FR-14-2). (2) The economy dials (Notoriety `bonus_*` multipliers, Heat→payout
> `heat_multiplier_*` slope, `legacy_floor`, `objective_notoriety`) moved into hot-editable
> `data/economy.json` (`EconomyConfigDef`, `Content.economy`); RunManager reads them via `_econ()`.
> `ProgressionConfigDef` keeps the streak *structure* (level thresholds, Edge weights). Attribute
> `cost_curve`s / Perk `legacy_cost`s stay `.tres`, range-checked by `EconomyValidator` (FR-14-4).
> Also closed a task-12 leftover: the `financier` Perk's `legacy_conversion_mult` is now consumed in
> `end_streak`. FR-14-2/3/4 ticked below.

**Milestone:** M2 (wiring) · M3 (tuning) · **Depends on:** 08, 12, 13 · **Blocks:** —
**Implements:** GDD §12 · **Decisions:** Q4 (keep three currencies).

## Overview
Wire and then *tune* the three-currency economy so push-your-luck, anti-frustration,
and "earn the whole score" all hold. All curves are data so balancing ships without
code (and so The Take could be folded into Notoriety later if needed — Q4 flip-point).

## Functional Requirements
- **FR-14-1** Three currencies behave per the GDD matrix: Notoriety (run score→Legacy), The Take (per-Streak cash for consumables/tools/ammo/Intel), Legacy (permanent).
- **FR-14-2** The Take = a % of secured cash value; spent at Fence/Planning Table; resets on Catch; never converts to Legacy.
- **FR-14-3** Notoriety multipliers (stealth/no-kill/speed/no-alarm/full-clear/bonus) are configurable data.
- **FR-14-4** Cost/value tables (loot values, gear research/restock, attribute curves, perk costs, Intel prices) live in `data/` and are hot-editable.
- **FR-14-5** Tuning targets are encoded as checkable invariants: a Streak averages "several missions"; first Legacy buys are cheap+impactful; Heat curve makes "run hot" tempting without making "play clean" pointless; every Catch affords something.
- **FR-14-6** A balancing harness can simulate runs from data to sanity-check curves before playtest.

## Phases
### Phase 14.1 — Currency wiring (M2)
- [x] The Take accrual + spend sinks (Fence/Planning); reset-on-Catch. *(FR-14-2: `DropPoint.bank()`
  splits Notoriety=full / Take=`take_fraction` cut via `EconomyConfigDef.take_cut`; sinks unchanged.)*
- [x] Multiplier config surfaced from data; Notoriety pipeline reads it. *(RunManager `_econ()` sources
  the dials from `data/economy.json`; `stack_multiplier` reads the config's `bonus_*`.)*

### Phase 14.2 — Data tables
- [x] Externalize all costs/values/curves to `data/*.json`; loaders + validation. *(Chosen scope:
  central `data/economy.json` (`EconomyConfigDef`, 20th `Content` registry) for the global economy dials,
  loaded by the existing `ContentRegistry` JSON path; `EconomyValidator` range-checks every per-item
  `.tres` cost table (loot/gear/attr/perk/intel) + the economy dials. Per-item costs stay `.tres`.)*

### Phase 14.3 — Balancing harness & passes
- [x] Monte-Carlo-ish run simulator over data; report Streak-length distribution + Legacy/run.
  *(`EconomySimulator` — CLEAN vs LOUD cohorts, seeded/headless; reuses the real payout seams.)*
- [x] Iterate curves to hit tuning targets; record decisions (see Balance pass below).

## Tests (GUT)
- [x] `test_take_lifecycle.gd` — Take = fraction of secured cash, spends at Planning Table, resets on Catch, never becomes Legacy.
- [x] `test_multiplier_config.gd` — changing a multiplier in the config changes the Notoriety result; economy.json hydrates.
- [x] `test_data_tables_valid.gd` — every cost/curve table loads and passes `EconomyValidator` schema/range checks (+ a not-a-rubber-stamp proof).
- [x] `test_tuning_invariants.gd` — simulated average Streak length in the target band, min payout ≥ floor, and clean strictly beats loud.
- [x] `test_economy_scenes.gd` — the Economy Sandbox greybox instantiates + the harness runs from config.

## Definition of Done
- [x] FR-14-1..6 satisfied; phases checked; tests green *(311/311 headless GUT on Godot 4.6.3, +15 task-14)*.
- [x] Curves hit the tuning targets in the harness; ready for human playtest passes.

## Balance pass (recorded decisions — stealth-focused, "loud is a last resort")
Dials in `game/data/economy.json` (hot-editable): `take_fraction=0.35`, `heat_multiplier_slope=0.5`
(modest payout bump), `catch_per_heat=0.55` (steep — a hot Streak dies fast), stealth bonuses
`stealth 0.60 / no_alarm 0.40 / no_kill 0.40 / full_clear 0.50`, `legacy_floor=150`. Intel re-priced to
the new Take reality (manifest 2000→1200, modifiers 3000→1800, silent_alarms 4000→2400) so casing stays
usable on a clean run. **Harness (20k runs/cohort):** clean mean **4.47** contracts (target band 3–7),
Legacy/run **~35.3k**, Take/run **~7.8k**, min payout **150** (the floor); loud mean **1.51** contracts,
Legacy/run **~13.8k** → **clean/loud Legacy ratio 2.55×**. Every Catch affords the cheapest Training buy
(100 ≤ floor 150).

**F6 "feel" playtest signed off 2026-07-04** on `game/scenes/economy/EconomyGreybox.tscn` (secure loot →
the Notoriety-full / Take-fraction split reads live; spend Take at Fence/Planning + Legacy at Training;
`[H]` Heat, `[C]` complete, `[K]` get Caught → convert; `[B]` balance report) — **Task 14 complete
(`[x]`).** **Deferred (↩):** in-mission Take/Heat HUD → 15; economy ↔ SaveManager → 16; daily/seeded
balance presets → 20. (M2/M3 milestone *gates* still need their other spanned tasks.)
