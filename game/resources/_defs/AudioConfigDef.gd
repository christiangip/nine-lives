extends Resource
class_name AudioConfigDef
## Tunables for the audio layer (task 17): the diegetic cue → asset map, music crossfade timing +
## procedural placeholder-bed parameters, guard-footstep cadence, and 3D attenuation. Keeps
## AudioManager free of magic numbers. Instance lives as game/resources/audio/default_audio.tres
## (registered as Content.audio); AudioManager resolves &"default" with a .new() fallback so headless
## seams never crash. Cues are approximated from the imported Kenney CC0 SFX (bespoke SFX/music pending
## — see ART-TODO). See docs/tasks/17_audio.md and GDD §14.

@export var id: StringName = &"default"   ## registry key; presets/mixes can coexist

const _SFX_ROOT := "res://game/assets/audio/sfx/"

## Diegetic cue id → OGG path (FR-17-2). Approximated from the Kenney interface/impact sets.
@export var sfx_paths: Dictionary = {
	&"spotted": _SFX_ROOT + "interface/glitch_002.ogg",
	&"alarm_loud": _SFX_ROOT + "interface/error_005.ogg",
	&"alarm_silent": _SFX_ROOT + "interface/question_003.ogg",
	&"takedown": _SFX_ROOT + "impact/impactPunch_medium_000.ogg",
	&"body_found": _SFX_ROOT + "interface/glitch_004.ogg",
	&"drill_run": _SFX_ROOT + "impact/impactMining_000.ogg",
	&"drill_jam": _SFX_ROOT + "interface/error_002.ogg",
	&"drill_done": _SFX_ROOT + "interface/confirmation_002.ogg",
	&"hack_tick": _SFX_ROOT + "interface/tick_001.ogg",
	&"hack_fault": _SFX_ROOT + "interface/error_006.ogg",
	&"hack_done": _SFX_ROOT + "interface/confirmation_001.ogg",
	&"lockpick_snap": _SFX_ROOT + "impact/impactMetal_light_000.ogg",
	&"loot_pickup": _SFX_ROOT + "interface/pluck_001.ogg",
	&"loot_secured": _SFX_ROOT + "interface/confirmation_003.ogg",
	&"mission_win": _SFX_ROOT + "interface/confirmation_004.ogg",
	&"streak_caught": _SFX_ROOT + "interface/bong_001.ogg",
}

## Cues that surface an on-screen caption when audio.subtitles is on (FR-17-7): cue id → caption text.
@export var captions: Dictionary = {
	&"spotted": "[!] Spotted",
	&"alarm_loud": "[!!] Alarm — going loud",
	&"alarm_silent": "[!] Silent alarm tripped",
	&"takedown": "[*] Takedown",
	&"loot_secured": "[$] Loot secured",
	&"streak_caught": "[X] Caught",
}

## Footstep variants (FR-17-3); a random one plays per step for player + guards.
@export var footstep_paths: Array[String] = [
	_SFX_ROOT + "impact/footstep_concrete_000.ogg",
	_SFX_ROOT + "impact/footstep_concrete_001.ogg",
	_SFX_ROOT + "impact/footstep_concrete_002.ogg",
	_SFX_ROOT + "impact/footstep_concrete_003.ogg",
	_SFX_ROOT + "impact/footstep_concrete_004.ogg",
]

# --- Diegetic SFX routing --------------------------------------------------
@export var sfx_3d_max_distance: float = 28.0   ## 3D falloff radius for positional cues
@export var footstep_min_gap: float = 0.11      ## per-source throttle so footsteps don't machine-gun
@export var guard_step_interval: float = 0.5    ## guard footstep cadence while moving (locatable by ear)

# --- Music beds (FR-17-1) — procedural placeholder; swap for real stems later ---
@export var music_crossfade_time: float = 1.5   ## state→state stem crossfade (seconds)
@export var music_root_hz: float = 55.0         ## A1 drone root the beds are built from
@export var music_bed_seconds: float = 2.0      ## length of each looped bed buffer
@export var music_bed_db: float = -14.0         ## base loudness of a bed at full state weight
## Per MusicState {CALM,TENSE,COMBAT,RESOLVE}: pitch offset (semitones) + partial count (rising tension).
@export var music_state_semitones: PackedInt32Array = PackedInt32Array([0, 3, 7, 5])
@export var music_state_partials: PackedInt32Array = PackedInt32Array([2, 3, 5, 4])

## The audio config in effect: Content.audio's &"default", or a schema-default fallback so headless
## seams never crash. Mirrors EconomyConfigDef.resolve().
static func resolve() -> AudioConfigDef:
	var c := Services.content()
	if c != null and c.audio != null:
		var d := c.audio.get_def(&"default") as AudioConfigDef
		if d != null:
			return d
	return AudioConfigDef.new()
