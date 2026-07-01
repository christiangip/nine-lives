extends Obstacle
class_name DisplayCase
## A museum/vault display case (FR-06-4, GDD §9.1). Four ways in, each a different risk: a matching
## KEY/lock, a HACK (e-lock overlay, task 07), a silent GLASSCUTTER (gadget, task 09), or a SMASH —
## instant but sets off a loud alarm and draws guards. The quiet routes expose you while you work;
## the smash commits the location to alert.
## See docs/tasks/06_heist_mechanics_obstacles.md (FR-06-4).

# minigame_requested is declared on Obstacle (the base) — task 07 mounts the e-lock hack overlay on it.

func _has_glasscutter(by: Node) -> bool:
	# Glasscutter is task 09; duck-type an optional gadget until then. TODO[09].
	return by != null and by.has_method("has_glasscutter") and by.has_glasscutter()

# --- Open methods ----------------------------------------------------------
func use_key(by: Node) -> bool:
	if solved or def == null or not Obstacle.actor_has_item(by, def.required_item):
		return false
	_mark_solved(&"key")
	return true

func cut(by: Node) -> bool:
	if solved or not _has_glasscutter(by):
		return false
	_mark_solved(&"glasscutter")   # silent
	return true

## Instant + loud: shatters the glass, trips a loud alarm and makes noise.
func smash() -> void:
	if solved:
		return
	_trip_alarm("loud")
	_mark_solved(&"smash")   # _mark_solved emits the smash noise from the def's profile

func hack(_by: Node) -> void:
	if not solved:
		minigame_requested.emit(&"hack")   # MinigameHost mounts the e-lock hack; result → apply_minigame_result

## Host callback: a solved hack opens the case (the quiet route). Failure/abort leaves it shut.
func apply_minigame_result(kind: StringName, success: bool) -> void:
	if kind == &"hack" and success:
		_mark_solved(&"hack")

## Default tap takes the safest available quiet route (key, then glasscutter, else request a hack).
## Smashing is a deliberate loud choice surfaced by the HUD (task 15).
func interact(by: Node) -> void:
	if solved or def == null:
		return
	if use_key(by):
		return
	if cut(by):
		return
	hack(by)
