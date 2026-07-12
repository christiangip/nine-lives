extends Node3D
class_name Interactable
## Base for anything the player can interact with (doors, loot, panels, safes).
## See docs/tasks/06_heist_mechanics_obstacles.md.

@export var prompt: String = "Interact"
@export var hold_seconds: float = 0.0   ## 0 = instant tap

func can_interact(_by: Node) -> bool:
	return true

func interact(_by: Node) -> void:
	pass # TODO[06]: override per subtype

## In-world progress 0..1 of an interaction already under way (e.g. a proximity hack filling), so the HUD
## can draw a hold-to-interact ring for it. 0 for instant taps and idle targets. Override per subtype.
func interaction_progress() -> float:
	return 0.0

## Is a CHANNELLED interaction running on this target right now — one the player started and must keep
## standing there for (a HackTarget's timed fill)? PlayerController applies the gameplay/interaction_movement
## rule to it: either moving cancels it, or the player is locked in place until it finishes. (misc-fixes-5)
##
## Default false, and that default is load-bearing, not laziness:
##   • instant taps (loot, keycard doors) finish inside one frame — there is nothing to interrupt;
##   • MODAL minigame overlays (lockpick/safe/keypad/pickpocket) freeze the world, so the player can't
##     move anyway;
##   • a BREACH is deliberately exempt — a running drill screams for guards and MUST keep grinding while
##     you leave it to fight them (GDD §9.6). Only its jam repair is proximity-gated.
func is_channeling() -> bool:
	return false

## Abort a channelled interaction (the player moved, or pressed interact again to cancel). Idempotent;
## default no-op. Override alongside is_channeling().
func cancel_interaction() -> void:
	pass
