# Technical Architecture

Companion to GDD §16. This is the contract every sub-system task list builds against.

## Boot & scene flow

```
Main.tscn (boot)
  └─> MainMenu  ──New Game──> (first time) Tutorial ──> Hideout
        │      ──Continue──> SaveManager.load_slot() ──> Hideout
        ▼
     Hideout (stations as sub-scenes) ──Job Map──> MissionGenerator.build() ──> Mission
        ▲                                                      │
        └────────────── Mission results / Catch ◄─────────────┘
```

`GameManager` owns the top-level state machine `BOOT → MAIN_MENU → HIDEOUT → MISSION → MISSION_RESULTS`. Scene swaps go through `GameManager`, never ad-hoc `change_scene` calls scattered in gameplay code. Cross-cutting events flow through `EventBus` signals so systems stay decoupled.

## Autoload singletons (order matters)

Declared in `project.godot [autoload]`, loaded top-to-bottom:

1. **EventBus** — signals only, zero logic. The nervous system. Everything else may connect here.
2. **GameManager** — app state + scene transitions.
3. **InputManager** — remappable actions (KB+M + gamepad); persists rebinds.
4. **SaveManager** — 10-slot I/O, autosave, `scan_slots()` (drives Continue).
5. **ProgressionManager** — permanent account (Legacy, attributes, unlocks, Hideout state, Stash).
6. **RunManager** — current Streak (Notoriety, level, Edges, Heat, Take, Job Map, `committed`).
7. **MissionGenerator** — seeded hybrid-procedural assembly + population + solvability validation.
8. **AudioManager** — dynamic music layers + SFX bus.

**Dependency rule:** managers depend *downward* (e.g. `RunManager` may read `ProgressionManager`, not vice-versa) and communicate *sideways* only via `EventBus`. No two managers hold hard references to each other's mutable state.

## Data-driven content (the expandability backbone)

All content is a Godot `Resource` subclass (schemas in `game/resources/_defs/`) instanced as `.tres`, or JSON in `game/data/` for bulk/external authoring. A content addition = **author a resource (+ a scene where needed)**, never edit a central `match`/`switch`.

| Schema (`_defs/`) | Instances live in | Consumed by |
|---|---|---|
| `LootDef` | `resources/loot/`, `data/*.json` | Inventory, MissionGenerator |
| `GearDef` | `resources/gear/` | Armory, Workshop, Combat |
| `EdgeDef` / `PerkDef` | `resources/edges/` `perks/` | RunManager / ProgressionManager |
| `ArchetypeDef` | `resources/archetypes/` | MissionGenerator |
| `ObjectiveDef` / `ModifierDef` | `resources/objectives/` `modifiers/` | MissionGenerator, Economy |
| `EnemyDef` | `resources/enemies/` | AI, Pursuit |
| `AttributeDef` | `resources/attributes/` | Training, all gated systems |
| `StationDef` | `resources/stations/` | Hideout (manifest-driven) |
| `IntelDef` | `resources/intel/` | Planning Table, Economy |

**Content registries:** at boot, lightweight registries scan their folders (`ResourceLoader` / `DirAccess`) and index defs by `id`. Systems look content up by id, so new files appear automatically without code edits. (Built in `02_core_architecture.md`.)

## EventBus signal catalogue

The authoritative list lives in `game/autoload/EventBus.gd`. Categories: detection (`detection_changed`, `noise_emitted`, `player_spotted`, `body_discovered`), alarms/pursuit (`alarm_tripped`, `heat_changed`, `pursuit_phase_changed`), loot/objectives (`loot_picked_up`, `loot_secured`, `carry_changed`, `objective_updated`), run/progression (`notoriety_gained`, `streak_level_up`, `streak_ended`, `mission_completed`), and meta (`scene_transition_requested`, `save_completed`, `settings_changed`). **Add new signals here, document them, keep the file logic-free.**

## Save schema (10 slots)

One file per slot under `user://saves/slot_<n>.save` (JSON or `Resource` serialization). Top-level keys:

```jsonc
{
  "schema_version": 1,
  "meta":     { "playtime_s": 0, "last_played": "ISO8601", "last_contract": "", "streak_len": 0, "legacy": 0 },
  "permanent":{ "legacy": 0, "attributes": {}, "unlocked_gear": [], "research_done": [],
                "meta_perks": [], "stations_unlocked": [], "stash": [], "stats": {} },
  "streak":   { "notoriety": 0, "streak_level": 1, "edges": [], "heat": 0.0, "take": 0,
                "job_board": [/* contracts + seeds */], "committed": false, "between_missions": true }
}
```

`meta` is read cheaply by the slot popup *without* loading the whole save. `schema_version` drives migration (`16_save_system.md`). **Strict policy (Q5):** the only valid in-mission checkpoint is "between missions at the Hideout"; an active alarm (`streak.committed == true`) means relaunch resolves as the Catch.

## Mission runtime

`MissionGenerator.build(contract)` returns a `Node3D` mission root containing: the assembled geometry (prefab sections + setpieces), populated actors (guards/cameras/dogs/civilians from `EnemyDef`), loot nodes (from the archetype loot table), obstacles, Drop Points, and the Escape. A `MissionController` (scene-local) owns per-mission state (objective progress, secured value, Pursuit phase) and emits to `EventBus`. **Invariant tested in CI:** `validate_layout()` must prove a navigable, stealth-viable path entry → objective → escape for every seed in the test set.

## AI, navigation, performance

Guards/cameras/dogs are state machines (`GuardAI`, etc.) over `NavigationServer3D`. Vision = raycast LoS + cone angle + distance + light sample; hearing = subscriptions to `noise_emitted` within radius. Budget: cap concurrent "thinking" AI, stagger ticks (round-robin), and lean on low-poly + occlusion for the 60 FPS target. Profile before reaching for C#.

## Threading & determinism

Generation is seeded (`RandomNumberGenerator` per mission) for reproducibility. Keep gameplay logic on the main thread unless profiling forces worker threads for generation; if so, generation must remain pure/deterministic given a seed.
