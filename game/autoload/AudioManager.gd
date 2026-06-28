extends Node
## AudioManager — dynamic music layers + SFX bus routing.
## Autoload. Music responds to detection/pursuit state (calm->tense->combat->resolve).
## See docs/tasks/17_audio.md and GDD §14.

enum MusicState { CALM, TENSE, COMBAT, RESOLVE }

var music_state: int = MusicState.CALM

func _ready() -> void:
	# TODO[17]: connect EventBus.detection_changed / pursuit_phase_changed
	pass

func set_music_state(s: int) -> void:
	pass # TODO[17]: crossfade layered stems

func play_sfx(id: StringName, position = null) -> void:
	pass # TODO[17]: 3D positional when position given, else 2D UI bus

func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
