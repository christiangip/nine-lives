extends Node
## AudioManager — dynamic music layers + diegetic SFX bus routing (task 17).
## Autoload. Music responds to detection/pursuit state (calm→tense→combat→resolve) by crossfading
## looped stem beds; diegetic SFX route 3D (positional) or 2D. Built on the frozen EventBus — it
## *subscribes* to the existing globals and exposes a local caption_requested signal (EventBus stays
## signals-only). Tunables live in AudioConfigDef (Content.audio); no magic numbers.
## Music beds are procedural placeholders (see AudioConfigDef) — swap for real stems later.
## See docs/tasks/17_audio.md and GDD §14.

enum MusicState { CALM, TENSE, COMBAT, RESOLVE }

## DetectionSensor.DetectionState values, mirrored locally so the pure seam has no node dependency.
const DET_UNAWARE := 0
const DET_SUSPICIOUS := 1
const DET_SEARCHING := 2
const DET_ALERTED := 3

const _SILENT_DB := -80.0

## Emitted when a critical cue plays; the HUD renders it when audio.subtitles is on (FR-17-7).
signal caption_requested(text: String)

var music_state: int = MusicState.CALM
var _last_sfx_id: StringName = &""        ## observable for tests (test_sfx_event_hooks)

var _bed_players: Array[AudioStreamPlayer] = []
var _beds_built: bool = false
var _actor_states: Dictionary = {}         ## actor_id -> DetectionState (UNAWARE actors are pruned)
var _pursuit_phase: int = 0
var _resolving: bool = false               ## RESOLVE latched until we leave the mission
var _last_play: Dictionary = {}            ## throttle key -> msec

func _ready() -> void:
	_build_beds()
	_connect(EventBus.detection_changed, _on_detection_changed)
	_connect(EventBus.pursuit_phase_changed, _on_pursuit_phase_changed)
	_connect(EventBus.player_spotted, _on_player_spotted)
	_connect(EventBus.alarm_tripped, _on_alarm_tripped)
	_connect(EventBus.body_discovered, _on_body_discovered)
	_connect(EventBus.loot_secured, _on_loot_secured)
	_connect(EventBus.loot_picked_up, _on_loot_picked_up)
	_connect(EventBus.noise_emitted, _on_noise_emitted)
	_connect(EventBus.mission_completed, _on_mission_completed)
	_connect(EventBus.streak_ended, _on_streak_ended)
	_connect(EventBus.game_state_changed, _on_game_state_changed)

func _connect(sig: Signal, cb: Callable) -> void:
	if not sig.is_connected(cb):
		sig.connect(cb)

func _cfg() -> AudioConfigDef:
	return AudioConfigDef.resolve()

# --- Music: state machine + crossfade (FR-17-1) ----------------------------
## Pure seam: the MusicState for a detection level + pursuit phase. Pursuit (any phase ≥ 1) or a full
## spot → Combat; a lead (suspicious/searching) → Tense; otherwise Calm. Resolve is event-driven.
static func music_state_for(detection_state: int, pursuit_phase: int) -> int:
	if pursuit_phase >= 1 or detection_state >= DET_ALERTED:
		return MusicState.COMBAT
	if detection_state >= DET_SUSPICIOUS:
		return MusicState.TENSE
	return MusicState.CALM

## Crossfade to a music state: raise the target bed to full weight, drop the rest to silence.
func set_music_state(s: int, instant: bool = false) -> void:
	if s == music_state and _beds_built and not instant:
		return
	music_state = s
	var cfg := _cfg()
	var t := 0.0 if instant else cfg.music_crossfade_time
	for i in _bed_players.size():
		var target_db: float = cfg.music_bed_db if i == s else _SILENT_DB
		var p := _bed_players[i]
		if instant or not is_inside_tree():
			p.volume_db = target_db
		else:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", target_db, t)

func _recompute_music() -> void:
	if _resolving:
		return
	set_music_state(music_state_for(_worst_detection(), _pursuit_phase))

func _worst_detection() -> int:
	var worst := DET_UNAWARE
	for v in _actor_states.values():
		if int(v) > worst:
			worst = int(v)
	return worst

func _build_beds() -> void:
	var cfg := _cfg()
	for s in MusicState.size():
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.stream = _make_bed(cfg, s)
		p.volume_db = _SILENT_DB
		add_child(p)
		p.play()
		_bed_players.append(p)
	_beds_built = true
	set_music_state(MusicState.CALM, true)

## Build a looped placeholder bed: a detuned additive-harmonic drone with a slow tremolo. More partials
## + higher pitch = tenser state. Deterministic + headless-safe (tests never play it).
func _make_bed(cfg: AudioConfigDef, state: int) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * cfg.music_bed_seconds)
	var semis: int = cfg.music_state_semitones[state] if state < cfg.music_state_semitones.size() else 0
	var partials: int = cfg.music_state_partials[state] if state < cfg.music_state_partials.size() else 2
	var root := cfg.music_root_hz * pow(2.0, float(semis) / 12.0)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / float(rate)
		var sample := 0.0
		for h in partials:
			sample += sin(TAU * root * float(h + 1) * t) / float(h + 1)
		sample *= 0.5 * (1.0 + 0.3 * sin(TAU * 0.5 * t))   # tremolo
		var v := int(clampf(sample * 0.6, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav

# --- SFX (FR-17-2, FR-17-3) ------------------------------------------------
## Play a diegetic cue by id. `position` (a Vector3) routes a transient AudioStreamPlayer3D so the cue
## is locatable by ear; otherwise a 2D player. Unknown ids no-op safely. Fires a caption if mapped.
func play_sfx(id: StringName, position = null) -> void:
	_last_sfx_id = id
	var cfg := _cfg()
	_maybe_caption(id, cfg)
	var path := String(cfg.sfx_paths.get(id, ""))
	if path == "":
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if position is Vector3:
		_play_3d(stream, position, cfg.sfx_3d_max_distance)
	else:
		_play_2d(stream, "SFX")

## A random footstep at a world position (FR-17-3), throttled per source so multiple walkers don't
## machine-gun. `source` keys the throttle (the player + each guard get their own cadence).
func play_footstep(position: Vector3, source: String = "player") -> void:
	var cfg := _cfg()
	if cfg.footstep_paths.is_empty():
		return
	if not _throttle_ok("footstep_" + source, cfg.footstep_min_gap):
		return
	var path: String = cfg.footstep_paths[randi() % cfg.footstep_paths.size()]
	var stream := load(path) as AudioStream
	if stream != null:
		_play_3d(stream, position, cfg.sfx_3d_max_distance)

## Start a looping positional cue (e.g. a running drill) and return the player so the caller can stop
## it (queue_free) when the action ends. null if the cue id is unmapped. The stream is duplicated so
## toggling loop doesn't mutate the shared cached resource.
func play_loop(id: StringName, position: Vector3) -> AudioStreamPlayer3D:
	var cfg := _cfg()
	var path := String(cfg.sfx_paths.get(id, ""))
	if path == "":
		return null
	var base := load(path) as AudioStream
	if base == null:
		return null
	var stream := base.duplicate() as AudioStream
	if "loop" in stream:
		stream.set("loop", true)
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.max_distance = cfg.sfx_3d_max_distance
	add_child(p)
	p.global_position = position
	p.play()
	return p

func _play_3d(stream: AudioStream, position: Vector3, max_distance: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.max_distance = max_distance
	add_child(p)
	p.global_position = position
	p.finished.connect(p.queue_free)
	p.play()

func _play_2d(stream: AudioStream, bus: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func _maybe_caption(id: StringName, cfg: AudioConfigDef) -> void:
	var text := String(cfg.captions.get(id, ""))
	if text != "":
		caption_requested.emit(text)

func _throttle_ok(key: String, gap: float) -> bool:
	var now := Time.get_ticks_msec()
	var last := int(_last_play.get(key, -100000))
	if float(now - last) / 1000.0 < gap:
		return false
	_last_play[key] = now
	return true

# --- EventBus subscribers (EventBus stays frozen) --------------------------
func _on_detection_changed(actor_id: int, state: int, _fill: float) -> void:
	if state <= DET_UNAWARE:
		_actor_states.erase(actor_id)
	else:
		_actor_states[actor_id] = state
	_recompute_music()

func _on_pursuit_phase_changed(phase: int) -> void:
	_pursuit_phase = phase
	_recompute_music()

func _on_player_spotted(_by_actor_id: int) -> void:
	play_sfx(&"spotted")

func _on_alarm_tripped(kind: String, position: Vector3) -> void:
	play_sfx(&"alarm_loud" if kind == "loud" else &"alarm_silent", position)

func _on_body_discovered(position: Vector3) -> void:
	play_sfx(&"body_found", position)

func _on_loot_secured(_loot_id: String, _value: int) -> void:
	play_sfx(&"loot_secured")

func _on_loot_picked_up(_loot_id: String) -> void:
	play_sfx(&"loot_pickup")

func _on_noise_emitted(position: Vector3, _radius: float, source: String) -> void:
	if source == "footstep":
		play_footstep(position, "player")

func _on_mission_completed(_summary: Dictionary) -> void:
	_resolving = true
	set_music_state(MusicState.RESOLVE)
	play_sfx(&"mission_win")

func _on_streak_ended(_reason: String, _legacy_awarded: int) -> void:
	_resolving = true
	set_music_state(MusicState.RESOLVE)
	play_sfx(&"streak_caught")

func _on_game_state_changed(_previous: int, _next: int) -> void:
	# Leaving/entering a top-level state resets the soundscape to calm.
	_actor_states.clear()
	_pursuit_phase = 0
	_resolving = false
	set_music_state(MusicState.CALM)

# --- Bus routing (FR-17-4; SettingsManager._apply_audio drives the sliders) --
func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
