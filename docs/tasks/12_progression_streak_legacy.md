# 12 — Progression: Streak & Legacy

**Milestone:** M1 · **Depends on:** 02, 08 · **Blocks:** 13, 14, 20
**Implements:** GDD §5 · **Decisions:** Q3 (Legacy naming), Q4 (three currencies).

## Overview
The roguelite engine: per-run **Streak** (Notoriety → Streak Levels → Edges, Heat)
and permanent **Legacy** (attributes, unlocks, perks). Every Catch converts
Notoriety → Legacy so the player always progresses. Runs through `RunManager` +
`ProgressionManager`.

## Functional Requirements
- **FR-12-1** Notoriety accrues from secured loot value + objective completion × performance multipliers (stealth/no-kill/speed/no-alarm/full-clear/bonus).
- **FR-12-2** Notoriety raises Streak Level; each level offers a **choice of 1 of 3** random Edges from the pool; Edges apply modifiers while held and vanish on Catch.
- **FR-12-3** Heat rises on alarms/loud, persists for the Streak, raises later difficulty (11) **and** the conversion multiplier.
- **FR-12-4** On Catch: `Legacy = Notoriety × heat_multiplier`; `ProgressionManager.add_legacy()`; Streak resets to a low-difficulty board.
- **FR-12-5** Legacy spends at Hideout stations (13): Training (attributes), Workshop (research/unlocks), expansions, Legacy Perks.
- **FR-12-6** Attributes (`AttributeDef`, §5.5) raise via Training with a per-level Legacy cost curve; effects feed the relevant systems.
- **FR-12-7** Legacy Perks (`PerkDef`) are permanent always-on passives with prerequisites.
- **FR-12-8** Edge pool is data (`EdgeDef`), dozens at launch, rarity-weighted, tag-based for build identity.
- **FR-12-9** Every Catch pays out enough Legacy to afford *something* (anti-frustration floor).

## Phases
### Phase 12.1 — Streak core (M1)
- [ ] Notoriety accrual + multiplier stack; `notoriety_gained`.
- [ ] Streak Level thresholds + Edge draw-3 selection + apply/remove; `streak_level_up`.

### Phase 12.2 — Heat & conversion
- [ ] Heat accumulation + multiplier curve; future-difficulty handshake (11).
- [ ] Catch → conversion → `add_legacy` → `streak_ended` → reset.

### Phase 12.3 — Permanent line
- [ ] Attributes + cost curves + effect wiring; Legacy Perks + prerequisites.
- [ ] Edge/Perk content authoring (seed dozens of Edges, several Perks).

### Phase 12.4 — Balance hooks
- [ ] Expose all curves as data for 14; anti-frustration floor check.

## Tests (GUT)
- `test_notoriety_multipliers.gd` — stacked bonuses compute correctly; full-clear + stealth > unbonused.
- `test_edge_draw.gd` — level-up offers exactly 3 distinct Edges; choosing applies its modifier; reset removes it.
- `test_heat_multiplier.gd` — higher Heat yields a larger Legacy payout for equal Notoriety.
- `test_catch_conversion.gd` — Catch banks `Notoriety×mult` to Legacy and resets the Streak.
- `test_legacy_floor.gd` — even a minimal run pays ≥ the cheapest purchase.
- `test_attribute_costs.gd` — Training spends the right Legacy and applies the effect.

## Definition of Done
- [ ] FR-12-1..9 satisfied; phases checked; tests green.
- [ ] M1 manual: a full Streak→Catch→spend→stronger-next-run loop is felt.
