extends RefCounted
class_name RadioCheckin
## A downed guard's radio: HQ demands periodic "all-clear" check-ins. The player can fake a
## limited number (PayDay-pager style, GDD §8.5) by holding a prompt in time; once the fakeable
## budget is spent — or a demand goes unanswered — HQ escalates and the alarm trips.
## Pure logic + an EventBus.alarm_tripped emit; the on-screen prompt/timer widget is HUD task 15.
## See docs/tasks/05_ai_actors.md (FR-05-3, Phase 05.2).

var max_fakeable: int = 2          ## fakeable replies before HQ escalates (from AIConfigDef)
var fakes_used: int = 0            ## how many have been faked so far
var position: Vector3 = Vector3.ZERO   ## where the silent alarm originates (the downed guard)

func _init(p_max_fakeable: int = 2, p_position: Vector3 = Vector3.ZERO) -> void:
	max_fakeable = p_max_fakeable
	position = p_position

## True while fakeable budget remains (a successful "all clear" reply).
func can_fake() -> bool:
	return fakes_used < max_fakeable

## Attempt to fake an "all clear". Returns true if it held; false (and trips a silent alarm via
## EventBus) once the fakeable budget is exhausted. TODO[05].
func try_fake() -> bool:
	if can_fake():
		fakes_used += 1
		return true
	_escalate()
	return false

## A check-in demand that was missed (window elapsed / nobody answered) — immediate escalation.
func missed() -> void:
	_escalate()

func _escalate() -> void:
	EventBus.alarm_tripped.emit("silent", position)
