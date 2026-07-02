# 11 — Mission Generation

**Milestone:** M1 (basic) · M2 (full) · **Depends on:** 04, 05, 06, 08 · **Blocks:** 13, 14
**Implements:** GDD §7.5 · **Decisions:** **Q7 hybrid procedural**.

> **↩ From 05 (AI Actors):** the full sensor-actor roster (cameras/operator/dogs/civilians/
> inspector, Phase 05.3) and the AI perf budget (round-robin ticks / sleep distant actors,
> Phase 05.5) are deferred until there is a populated mission to host and profile them. Spawn
> them from `EnemyDef` here (`MissionGenerator.build`), then come back and tick 05.3/05.5 +
> DoD-M3 in `05_ai_actors.md`.

> **↩ From 06 (Obstacles):** every obstacle **publishes** its data — `Obstacle.solution_set()` +
> `difficulty()` over `Content.obstacles` (16 `ObstacleDef` archetypes). Consume it here (this is
> FR-06-10's consumer): place obstacles, **validate solvability** (≥1 reachable solution per gate;
> never minigame-only except pin-tumbler locks), scope **power zones** (fuse ↔ device `power_zone`),
> and **spawn the found clues/codes** (`clue_id`) that skip safes/keypads. Come back and tick
> DoD-M2 ("consumed by the generator") in `06_…md`.

> **↩ From 07 (Minigames):** when populating NPCs, drop a `MinigameHost` into the level and
> `attach_all(root)` so obstacle/NPC `minigame_requested` signals mount overlays; give each pickpockable
> civilian the `&"pickpocket"` requester seam (see `↩ From 07` in `05_ai_actors.md`). Then tick the
> pickpocket line in `07_minigames.md`.

> **↩ From 09 (Loadout/Gear):** the loadout is validated pre-mission (`Loadout.validate()` on the
> Streak's `RunManager.loadout()`) — call it before entering the mission (FR-09-8). Also **scatter
> consumables as loot** (FR-09-6 "some found as loot": `emp`/`smoke`/`throwing_coins`/`thermite` ×
> count) at loot anchors, routing them into `Loadout` on pickup, and give civilians a pickpockable
> keycard so the `keycard_cloner` gadget has a target. Come back and tick the "found-as-loot /
> loadout-into-mission" notes in `09_…md`.

## Overview
Seeded, hybrid-procedural assembly: hand-authored modular **sections** stitched by
a rule-based assembler, then **populated** with loot/guards/cameras/objectives —
always producing a *fair, legible, solvable* stealth space. Reproducible by seed.

## Functional Requirements
- **FR-11-1** Section prefabs declare connection **sockets**, guard-patrol anchors, loot anchors, cover, and entry/exit tags.
- **FR-11-2** The assembler builds a coherent floorplan per `ArchetypeDef`, honoring min/max sections and socket compatibility, with no overlaps.
- **FR-11-3** **Solvability guarantee:** every generated layout has a navigable, stealth-viable path entry→objective→escape and reachable Drop Points; `validate_layout()` proves it.
- **FR-11-4** Population scatters loot (archetype table), patrols, cameras, locks/hacks, and objective items across anchors within designer rules (e.g. "Mark in a high-security wing," "≥1 alternate entry").
- **FR-11-5** Objectives (Grab/Mark/Crack/Retrieve/Sabotage/Puzzle-room) + optional bonus objectives are placed per `ObjectiveDef`.
- **FR-11-6** Modifiers (`ModifierDef`) adjust difficulty/rewards and can inject hazards (extra patrols, blackout, silent-alarm heavy).
- **FR-11-7** Handcrafted **setpieces** (named vault, puzzle-room) drop in as special prefabs at designated slots.
- **FR-11-8** A **seed** fully determines a layout (reproducible for debugging + daily contracts, 20).
- **FR-11-9** Difficulty Tier + Heat parameterize guard count/skill, camera/laser density, lock/hack difficulty, police speed, advanced obstacles.
- **FR-11-10** `refresh_board()` produces 3–5 contracts escalating with Streak length + Heat.

## Phases
### Phase 11.1 — Prefab contract & a hand level (M1)
- [ ] Define socket/anchor metadata + `prefabs_meta` resources; author 4–6 sections + the M0 greybox.
- [ ] Minimal assembler: linear stitch + populate + `validate_layout()`.

### Phase 11.2 — Rule-based assembler (M2)
- [ ] Graph-based layout (branching, alternate entries), overlap avoidance, socket matching.
- [ ] Designer rule DSL for placement constraints.

### Phase 11.3 — Population & objectives
- [ ] Loot/guard/camera/lock scatter within rules; objective + bonus placement; setpiece insertion.
- [ ] Modifier application + Tier/Heat parameterization.

### Phase 11.4 — Board & seeds
- [ ] `refresh_board()` with escalation; seed plumbing; reproducibility.

## Tests (GUT)
- `test_layout_solvable.gd` — for a fixed seed set, entry→objective→escape nav path exists and is stealth-viable (gates CI).
- `test_no_overlap.gd` — assembled sections never overlap; all sockets matched or capped.
- `test_seed_reproducible.gd` — same seed → identical layout + population.
- `test_population_rules.gd` — Mark spawns in a high-security wing; ≥1 alternate entry exists.
- `test_board_escalation.gd` — higher Streak length/Heat raises the board's difficulty floor.

## Definition of Done
- [ ] M1: basic generator + one hand level + solvability test green.
- [ ] M2: full assembler/population/modifiers/setpieces; the slice archetype generates cleanly across seeds.
