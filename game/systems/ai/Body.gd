extends Node3D
class_name Body
## A downed/dead guard left in the world. Discoverable: a patrolling guard that sees an
## un-concealed body (in its cone, clear LoS) raises the alarm and starts searching (GDD §8.5,
## FR-05-2). Bodies can be dragged into cover/containers to conceal them — full carry/drag wiring
## is task 08; this exposes the `concealed` flag + a conceal toggle as the hook.
## Joins group &"body" so guards can scan for it. See docs/tasks/05_ai_actors.md (Phase 05.1).

@export var concealed: bool = false   ## hidden in cover/container → not discoverable
@export var lethal: bool = false      ## killed (vs choked out) — leaves blood; louder alarm later

var discovered: bool = false          ## latched once a guard has raised the alarm on it

func _ready() -> void:
	add_to_group(&"body")

## Drag/hide hook (full carry integration is task 08). TODO[08].
func set_concealed(value: bool) -> void:
	concealed = value

## Pure: should an observing guard raise the alarm on this body? Only an un-concealed body that
## is inside the guard's cone with a clear line of sight is discoverable.
static func raises_alarm(is_concealed: bool, in_cone: bool, has_los: bool) -> bool:
	return not is_concealed and in_cone and has_los

## Called by a guard that has spotted this body. Latches so the alarm fires once; raises a
## (silent) local alarm and announces the discovery for nearby guards to converge.
func discover() -> void:
	if discovered or concealed:
		return
	discovered = true
	EventBus.body_discovered.emit(global_position)
	EventBus.alarm_tripped.emit("silent", global_position)
