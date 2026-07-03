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
- [x] Notoriety accrual + multiplier stack; `notoriety_gained`.
- [x] Streak Level thresholds + Edge draw-3 selection + apply/remove; `streak_level_up`.

### Phase 12.2 — Heat & conversion
- [x] Heat accumulation + multiplier curve; future-difficulty handshake (11).
- [x] Catch → conversion → `add_legacy` → `streak_ended` → reset.

### Phase 12.3 — Permanent line
- [x] Attributes + cost curves + effect wiring; Legacy Perks + prerequisites.
- [x] Edge/Perk content authoring (seed dozens of Edges, several Perks).

### Phase 12.4 — Balance hooks
- [x] Expose all curves as data for 14; anti-frustration floor check.

## Tests (GUT)
- `test_notoriety_multipliers.gd` — stacked bonuses compute correctly; full-clear + stealth > unbonused.
- `test_edge_draw.gd` — level-up offers exactly 3 distinct Edges; choosing applies its modifier; reset removes it.
- `test_heat_multiplier.gd` — higher Heat yields a larger Legacy payout for equal Notoriety.
- `test_catch_conversion.gd` — Catch banks `Notoriety×mult` to Legacy and resets the Streak.
- `test_legacy_floor.gd` — even a minimal run pays ≥ the cheapest purchase.
- `test_attribute_costs.gd` — Training spends the right Legacy and applies the effect.

## Definition of Done
- [x] FR-12-1..9 satisfied; phases checked; tests green.
- [~] M1 manual: a full Streak→Catch→spend→stronger-next-run loop is felt. *(The
  Streak→Catch→conversion→board-escalation half is playable + F6-verifiable in
  `MissionGreybox.tscn` today; the **spend** half needs the Hideout stations (task 13) +
  menu/save flow (15/16). This is the **M1 milestone gate**, met once 13/15/16 land — not
  task 12 alone. Come back and tick it when signing off M1.)*

## Progress notes
- **Complete (code + automated DoD, verified green on Godot 4.6.3 — headless GUT 270/270,
  +25 task-12 tests).** The roguelite engine now runs end-to-end in data:
  - **Config:** a new **`ProgressionConfigDef`** (`Content.progression`, the **19th registry**)
    holds every curve — Streak-Level thresholds, the performance-bonus fractions, the Heat→payout
    slope, the anti-frustration `legacy_floor`, and Edge rarity weights — so 14 tunes without code.
  - **`RunManager`** grew the Streak brain as **pure static seams** (`level_for_notoriety`,
    `stack_multiplier`, `draw_edges`, `heat_multiplier_for`, `convert_to_legacy`) under thin glue:
    `add_notoriety` applies held-Edge `notoriety_mult` then draws-3 on a level-up
    (`streak_level_up`); a new `EventBus.mission_completed` listener banks objective NP ×
    performance multiplier + bumps `streak_length`; `end_streak` converts Notoriety × Heat-mult →
    Legacy (floored), banks it, emits `streak_ended`, and resets. **EventBus stayed frozen** (the
    three signals were pre-declared + contract-locked).
  - **`ProgressionManager`** grew the Legacy sinks: `train_attribute` (spends the `AttributeDef`
    cost curve, raises the level; `attribute_effect` feeds systems) and `buy_perk`/`can_buy_perk`
    (prereq + cost gated, permanent, idempotent) + `perk_modifier_total`.
  - **Content:** 20 `EdgeDef` (rarity-tiered, the GDD §5.1 roster), 8 `PerkDef` (with a
    prereq chain), and cost curves on all **14** GDD §5.5 attributes (added health/armor/speed/
    sneak/carry_weight/carry_volume/perception).
  - **Performance flags:** `MissionController._finish` adds `elapsed_seconds`/`no_kill` (lethal-Body
    count)/`full_clear` (bonus objective) to the summary; RunManager derives no-alarm/stealth from
    its own per-mission tracking (`alarm_tripped`/`player_spotted`).
  - **Closed the `TODO[12]` breadcrumbs:** MinigameHost/Minigame attribute injection now returns
    real levels; `Lock.apply_minigame_result` feeds Lockpicking level + the def's per-level snap
    reduction (no magic numbers). The task-10 `test_secured_safe_on_loud_catch` was updated to the
    now-real conversion (its own comment had deferred it here).
- **Residual (`[~]`):** the cross-task M1 "felt" loop above (needs 13/15/16).
