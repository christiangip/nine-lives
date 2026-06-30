# Systems → Task List map

Each system folder implements one (or part of one) sub task list in `docs/tasks/`.
Build order and dependencies are in `docs/tasks/00_MASTER_TASKLIST.md`.

| Folder | Implements | Task list |
|---|---|---|
| `stealth/` | Vision cones, light, sound, detection states | `04_stealth_detection.md` |
| `ai/` | Guards, cameras, dogs, civilians, inspectors | `05_ai_actors.md` |
| `obstacles/` | Locks, safes, lasers, sensors, power, breaching | `06_heist_mechanics_obstacles.md` |
| `minigames/` | Lockpick, safe, hack, keypad, pickpocket | `07_minigames.md` |
| `loot/` + `inventory/` | Loot, two-axis carry, drop points, secured-loot rule | `08_loot_inventory.md` |
| `combat/` + `pursuit/` | Cover-shooter, alarms, police/SWAT escalation | `10_going_loud_pursuit.md` |
| `missiongen/` | Seeded hybrid-procedural assembly + population | `11_mission_generation.md` |
| `progression/` | Notoriety, Edges, Heat, Legacy, attributes | `12_progression_streak_legacy.md` |
| `economy/` | Three currencies, multipliers, Intel/Take | `14_economy_balancing.md` |
| `save/` | 10-slot saves, autosave, scan, strict policy | `16_save_system.md` |
| `audio/` | Dynamic music layers, SFX bus | `17_audio.md` |
| `interaction/` | Shared interactable base + prompt system | `06_heist_mechanics_obstacles.md` |
| `core/` | Architecture backbone: `ContentRegistry` + `Services` locator | `02_core_architecture.md` |
