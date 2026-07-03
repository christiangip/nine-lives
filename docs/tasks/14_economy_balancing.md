# 14 — Economy & Balancing

> **↩ From 12 (Progression):** task 12 shipped the currency *plumbing* but left the tuning/externalization
> to you. Two concrete seams: (1) `RunManager.add_take()` is a 1:1 passthrough marked `TODO[14]` — make
> it FR-14-2's *%-of-secured-cash*. (2) The Notoriety performance multipliers already live as data on
> `ProgressionConfigDef` (`Content.progression`, exported fractions `bonus_stealth`/`bonus_no_alarm`/
> `bonus_no_kill`/`bonus_speed`/`bonus_full_clear`) + the Heat→payout `heat_multiplier_*` slope + the
> `legacy_floor` + attribute `cost_curve`s + Perk `legacy_cost`s — FR-14-4 wants these in hot-editable
> `data/*.json` and FR-14-3/5 wants them *tuned*. Come back and tick FR-14-2/3/4 here.

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
- [ ] The Take accrual + spend sinks (Fence/Planning); reset-on-Catch.
- [ ] Multiplier config surfaced from data; Notoriety pipeline reads it.

### Phase 14.2 — Data tables
- [ ] Externalize all costs/values/curves to `data/*.json`; loaders + validation.

### Phase 14.3 — Balancing harness & passes
- [ ] Monte-Carlo-ish run simulator over data; report Streak-length distribution + Legacy/run.
- [ ] Iterate curves to hit tuning targets; record decisions.

## Tests (GUT)
- `test_take_lifecycle.gd` — Take accrues from cash, spends at Fence, resets on Catch, never becomes Legacy.
- `test_multiplier_config.gd` — changing a multiplier in data changes the Notoriety result.
- `test_data_tables_valid.gd` — every cost/curve table loads and passes schema/range checks.
- `test_tuning_invariants.gd` — simulated average Streak length + min payout fall in target bands.

## Definition of Done
- [ ] FR-14-1..6 satisfied; phases checked; tests green.
- [ ] Curves hit the tuning targets in the harness; ready for human playtest passes.
