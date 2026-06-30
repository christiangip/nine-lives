extends Node
## EventBus — global signal hub for decoupling systems.
## Autoload. Systems emit/connect here instead of holding hard references.
## See docs/ARCHITECTURE.md §"EventBus" and docs/tasks/02_core_architecture.md.

# --- Stealth / detection (docs/tasks/04_stealth_detection.md) ---
signal detection_changed(actor_id: int, state: int, fill: float)   ## state = DetectionState enum
signal noise_emitted(position: Vector3, radius: float, source: String)
signal player_spotted(by_actor_id: int)
signal body_discovered(position: Vector3)

# --- Alarms / pursuit (docs/tasks/10_going_loud_pursuit.md) ---
signal alarm_tripped(kind: String, position: Vector3)             ## "silent" | "loud"
signal heat_changed(new_heat: float)
signal pursuit_phase_changed(phase: int)

# --- Loot / objectives (docs/tasks/08_loot_inventory.md) ---
signal loot_picked_up(loot_id: String)
signal loot_secured(loot_id: String, value: int)                 ## banked at a Drop Point / Escape
signal carry_changed(weight: float, volume: float)
signal objective_updated(objective_id: String, complete: bool)

# --- Run / progression (docs/tasks/12_progression_streak_legacy.md) ---
signal notoriety_gained(amount: int, total: int)
signal streak_level_up(new_level: int, edge_choices: Array)
signal streak_ended(reason: String, legacy_awarded: int)         ## the "Catch"
signal mission_completed(summary: Dictionary)

# --- Meta / flow (docs/tasks/02_core_architecture.md, 15_ui_hud_menus.md, 16_save_system.md) ---
signal scene_transition_requested(target: String, payload: Dictionary)
signal game_state_changed(previous: int, next: int)              ## GameManager.State enum
signal save_completed(slot: int)
signal settings_changed(section: String)

# TODO[02]: keep this file signals-only. No logic here.
