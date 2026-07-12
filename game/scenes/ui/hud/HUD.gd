extends CanvasLayer
class_name MissionHUD
## The in-mission HUD (task 15, FR-15-5/6/7) — the minimal, trustable, FP-readability overlay. Assembles:
## a crosshair + interaction prompt, the combined CompassEye detection indicator, a carry readout
## (W/V vs caps + FULL warning), an objective + secured-vs-remaining tracker, a Pursuit/Heat strip, and a
## loud block (health/armor/ammo) that only appears once committed/loud. Reads live state each frame from
## the player (&"player" group), the mission (&"mission_root" → MissionController) and RunManager, and binds
## the frozen EventBus (pursuit_phase_changed / heat_changed). Honours gameplay/ui_scale + reduce_flashing.
## Also owns the Pause overlay (the `pause` action). Minigame overlays are the diegetic FR-15-6 half, already
## shipped by task 07's MinigameHost. Built in code (house pattern). See docs/tasks/15_ui_hud_menus.md.

const PAUSE_SCENE := "res://game/scenes/mission/PauseMenu.tscn"
const _OUTLINE := 5

var _root: Control
var _crosshair: Control
var _prompt_label: Label
var _compass: CompassEye
var _carry_label: Label
var _carry_full: Label
var _objective_label: Label
var _secured_label: Label
var _objective_fill: ColorRect            ## secured-vs-remaining progress bar
var _escape_cue_label: Label              ## "Objective complete — reach an Escape" cue
var _objective_flash: float = 0.0         ## 0..1, decays; pulses the objective on a loot bank / objective tick
var _pursuit_label: Label
var _loud_box: Control
var _hp_fill: ColorRect
var _armor_fill: ColorRect
var _ammo_label: Label
var _reload_row: Control                  ## reload progress row (visible only while reloading)
var _reload_fill: ColorRect
var _stamina_box: Control                 ## its own fade — shown while stamina is draining/recovering
var _stamina_fill: ColorRect
var _hold_ring: HoldRing                  ## radial hold-to-interact progress around the crosshair
var _bar_w: float = 180.0

# Survival block fade (B1) + stamina fade — alpha lerps so the readouts glide in/out.
var _survival_alpha: float = 0.0
var _stamina_alpha: float = 0.0
var _stamina_cur: float = 0.0
var _stamina_max_v: float = 0.0
var _stamina_src: Node = null           ## the player we've connected stamina_changed to
# Detected tracking (drives the survival fade): actor_id -> detection state, mirrors CompassEye.
var _actor_states: Dictionary = {}
# Floating "-N" damage tick near the health bar.
var _dmg_tick_label: Label = null
var _dmg_tick_t: float = 0.0
# DOWNED overlay: a red screen tint + "DOWNED / press [F] to get up" + a revive-window countdown bar.
var _downed_box: Control = null
var _downed_prompt: Label = null
var _downed_bar: ColorRect = null
var _downed_bar_w: float = 240.0

var _phase: int = 0
var _pause_menu: Control = null
var _ui_scale: float = 1.0
var _caption_label: Label = null       ## audio captions (task 17, FR-17-7); shown only when subtitles on
var _caption_token: int = 0            ## generation guard so a new caption cancels the old clear timer
var _notice_label: Label = null        ## transient gameplay notices (carry-cap rejection, …); always shown
var _notice_token: int = 0             ## generation guard for the notice auto-clear
var _notice_src: Node = null           ## the player whose interaction_target_changed we're connected to
var _reject_src: Interactable = null   ## the interactable whose pickup_rejected we're currently listening to

# --- Damage feedback + hit marker (task 21 juice; honour reduce_flashing) ---
var _reduce_flashing: bool = false
var _damage_vignette: ColorRect = null
var _vignette_tween: Tween = null
var _last_health: float = -1.0
var _dot: Label = null                 ## crosshair centre; briefly tints on a confirmed hit
var _hit_flash: float = 0.0            ## 0..1, decays; a landed shot sets it to 1
var _hit_player: Node = null           ## the player whose shot_landed we're connected to

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep drawing + catch the resume key while the tree is paused
	_ui_scale = _read_ui_scale()
	_reduce_flashing = _read_reduce_flashing()
	_build()
	if not EventBus.pursuit_phase_changed.is_connected(_on_pursuit_phase):
		EventBus.pursuit_phase_changed.connect(_on_pursuit_phase)
	if not EventBus.settings_changed.is_connected(_on_settings_changed):
		EventBus.settings_changed.connect(_on_settings_changed)
	# Detection state feeds the survival-block fade-in (B1); loot/objective ticks flash the objective (B3).
	if not EventBus.detection_changed.is_connected(_on_detection_changed):
		EventBus.detection_changed.connect(_on_detection_changed)
	if not EventBus.loot_secured.is_connected(_on_loot_secured):
		EventBus.loot_secured.connect(_on_loot_secured)
	if not EventBus.objective_updated.is_connected(_on_objective_updated):
		EventBus.objective_updated.connect(_on_objective_updated)
	# Audio captions (FR-17-7): AudioManager emits a local caption per critical cue; we render it only
	# when the subtitles accessibility option is on.
	if AudioManager != null and not AudioManager.caption_requested.is_connected(_on_caption):
		AudioManager.caption_requested.connect(_on_caption)

# --- Pure seams (headless-testable) --------------------------------------------
## Carry is "full" (show the warning) once within a whisker of either cap. Pure. (FR-15-5)
static func carry_warning(w: float, v: float, wcap: float, vcap: float) -> bool:
	return (wcap > 0.0 and w >= wcap * 0.98) or (vcap > 0.0 and v >= vcap * 0.98)

## The loud block (health/armor/ammo) is shown only when the run has gone loud/committed, Pursuit is
## active, or the player has actually taken damage. Pure. (FR-15-5)
static func loud_visible(committed: bool, phase: int, health_frac: float) -> bool:
	return committed or phase > 0 or health_frac < 0.999

## Survival block visibility (B1): the loud conditions PLUS "a guard is actively onto you" (detected).
## So a pure-stealth player sees their health/armor the moment they're spotted, not only once loud.
## Persistence-once-committed falls out naturally — RunManager.committed latches for the mission. Pure.
static func survival_visible(committed: bool, phase: int, health_frac: float, detected: bool) -> bool:
	return loud_visible(committed, phase, health_frac) or detected

## The stamina bar shows only while stamina is below full (draining or recovering), so it never clutters
## idle sneaking. Pure.
static func stamina_visible(current: float, maximum: float) -> bool:
	return maximum > 0.0 and current < maximum * 0.999

## Any detector at Suspicious+ (state >= 1) means a guard is onto the player — the survival fade trigger.
## Pure. `states` is the collection of current per-actor detection states.
static func any_detected(states: Array) -> bool:
	for s in states:
		if int(s) >= 1:
			return true
	return false

## Secured-vs-total as a 0..1 fraction for the objective progress bar. Pure.
static func objective_fraction(secured: int, total: int) -> float:
	return clampf(float(secured) / float(total), 0.0, 1.0) if total > 0 else 0.0

# --- Build ---------------------------------------------------------------------
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.build()
	add_child(_root)
	_bar_w = 180.0 * _ui_scale   # set before any _mk_bar call (objective bar is built before the loud block)

	# Full-rect damage vignette, drawn behind the readouts so it never obscures them (FR-21-3).
	_damage_vignette = ColorRect.new()
	_damage_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_vignette.color = Color(0.8, 0.05, 0.05, 0.0)
	_damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_damage_vignette)

	_build_crosshair()
	_compass = CompassEye.new()
	_compass.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_compass.position = Vector2(-60, -170) * _ui_scale
	_compass.scale = Vector2.ONE * _ui_scale
	_root.add_child(_compass)

	# Top-left: carry readout + FULL warning.
	var tl := _corner_box(Control.PRESET_TOP_LEFT, Vector2(20, 18))
	_carry_label = _mk_label(tl, "", 20, UITheme.TEXT)
	_carry_full = _mk_label(tl, "", 18, UITheme.WARN)

	# Top-right: objective (headline hierarchy) + secured/remaining, a loot progress bar, and an
	# "objective complete → escape" cue.
	var tr := _corner_box(Control.PRESET_TOP_RIGHT, Vector2(-20, 18))
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_objective_label = _mk_label(tr, "", 26, UITheme.ACCENT)   # larger = clear headline hierarchy
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_secured_label = _mk_label(tr, "", 18, UITheme.OK)
	_secured_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_objective_fill = _mk_bar(tr, "LOOT", UITheme.OK)          # secured-vs-remaining reads faster as a bar
	_escape_cue_label = _mk_label(tr, "", 18, UITheme.WARN)
	_escape_cue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Bottom-left: a stamina bar (its own fade) above the Pursuit/Heat strip.
	var bl := _corner_box(Control.PRESET_BOTTOM_LEFT, Vector2(20, -18))
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_stamina_fill = _mk_bar(bl, "STAM", Color(0.3, 0.75, 0.45))
	_stamina_box = bl.get_child(bl.get_child_count() - 1) as Control   # the row _mk_bar just appended
	_stamina_box.modulate.a = 0.0
	_pursuit_label = _mk_label(bl, "", 20, UITheme.WARN)

	_build_loud_block()
	_build_downed_overlay()

	# Bottom-center caption line (subtitles).
	_caption_label = Label.new()
	_caption_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption_label.position = Vector2(-260, -70) * _ui_scale
	_caption_label.custom_minimum_size = Vector2(520, 0) * _ui_scale
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.add_theme_color_override("font_color", UITheme.TEXT)
	_caption_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption_label.add_theme_constant_override("outline_size", _OUTLINE)
	_root.add_child(_caption_label)

	# One line above the caption: transient gameplay notices (a pickup refused by the carry cap, …).
	# NOT subtitles-gated — this is a gameplay answer to "why didn't that work?", not an audio caption.
	_notice_label = Label.new()
	_notice_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notice_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice_label.position = Vector2(-260, -105) * _ui_scale
	_notice_label.custom_minimum_size = Vector2(520, 0) * _ui_scale
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.add_theme_color_override("font_color", UITheme.WARN)
	_notice_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_notice_label.add_theme_constant_override("outline_size", _OUTLINE)
	_root.add_child(_notice_label)

	# CRITICAL (FP mouse-look): every HUD element is a passive readout — none is meant to be clicked —
	# but Godot Controls default to MOUSE_FILTER_STOP, and mouse_filter does NOT inherit from a parent.
	# In captured mouse mode the cursor is pinned to screen centre, so the centre crosshair (and any
	# other element under the cursor) would CONSUME InputEventMouseMotion in the GUI phase before it
	# reaches PlayerController._unhandled_input — silently killing camera look while WASD still worked.
	# Force the whole display subtree transparent to the mouse. The Pause overlay is added as a separate
	# child of this CanvasLayer (not under _root), so its buttons stay clickable.
	_make_mouse_transparent(_root)

## Recursively set MOUSE_FILTER_IGNORE on a Control and all its descendants, so no passive HUD element
## can intercept mouse motion/clicks meant for gameplay (see the call site in _build). Future HUD
## elements are covered automatically — no need to remember to set the filter on each new Label.
static func _make_mouse_transparent(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_make_mouse_transparent(child)

func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.custom_minimum_size = Vector2(1, 1)
	_root.add_child(_crosshair)
	var dot := Label.new()
	dot.text = "+"
	dot.add_theme_font_size_override("font_size", int(22 * _ui_scale))
	dot.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	dot.position = Vector2(-8, -16)
	_crosshair.add_child(dot)
	_dot = dot
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", int(18 * _ui_scale))
	_prompt_label.add_theme_color_override("font_color", UITheme.ACCENT)
	_prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt_label.add_theme_constant_override("outline_size", _OUTLINE)
	_prompt_label.position = Vector2(-70, 22)
	_prompt_label.custom_minimum_size = Vector2(140, 0)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.add_child(_prompt_label)
	# Radial hold-to-interact progress ring, centred on the crosshair.
	_hold_ring = HoldRing.new()
	_hold_ring.size = Vector2(52, 52)
	_hold_ring.scale = Vector2.ONE * _ui_scale
	_hold_ring.position = Vector2(-26, -26) * _ui_scale
	_crosshair.add_child(_hold_ring)

func _build_loud_block() -> void:
	_loud_box = VBoxContainer.new()
	_loud_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_loud_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_loud_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_loud_box.position = Vector2(-20, -18)
	_loud_box.add_theme_constant_override("separation", 4)
	_loud_box.visible = false
	_root.add_child(_loud_box)
	_bar_w = 180.0 * _ui_scale
	_hp_fill = _mk_bar(_loud_box, "HEALTH", Color(0.85, 0.25, 0.25))
	_armor_fill = _mk_bar(_loud_box, "ARMOR", Color(0.35, 0.6, 0.95))
	_ammo_label = _mk_label(_loud_box, "", 20, UITheme.TEXT)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Reload progress bar — shown only while the weapon is actually reloading (B3).
	_reload_fill = _mk_bar(_loud_box, "RELOAD", Color(0.9, 0.8, 0.3))
	_reload_row = _loud_box.get_child(_loud_box.get_child_count() - 1) as Control
	_reload_row.visible = false

	# Floating "-N" damage tick, anchored just above the loud block (B2). Sits on _root so it can float
	# up independent of the VBox layout.
	_dmg_tick_label = Label.new()
	_dmg_tick_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dmg_tick_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_dmg_tick_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dmg_tick_label.add_theme_font_size_override("font_size", int(26 * _ui_scale))
	_dmg_tick_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	_dmg_tick_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_dmg_tick_label.add_theme_constant_override("outline_size", _OUTLINE)
	_dmg_tick_label.modulate.a = 0.0
	_root.add_child(_dmg_tick_label)

## DOWNED overlay (Part B / §8.7): a clear red screen tint + big "DOWNED" + a live get-up prompt and a
## revive-window countdown bar, so self-revive has real feedback (it was invisible before). Hidden until
## the player's Health enters DOWNED. Built under _root so _make_mouse_transparent covers it.
func _build_downed_overlay() -> void:
	_downed_box = Control.new()
	_downed_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_downed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_downed_box.visible = false
	_root.add_child(_downed_box)
	var tint := ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.5, 0.0, 0.0, 0.28)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_downed_box.add_child(tint)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.position = Vector2(-140, -70) * _ui_scale
	vb.custom_minimum_size = Vector2(280, 0) * _ui_scale
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	_downed_box.add_child(vb)
	var title := _mk_label(vb, "DOWNED", 40, Color(1.0, 0.4, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_downed_prompt = _mk_label(vb, "", 22, UITheme.TEXT)
	_downed_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_downed_bar_w = 240.0 * _ui_scale
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(_downed_bar_w, 14 * _ui_scale)
	vb.add_child(frame)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.06, 0.08, 0.85)
	frame.add_child(bg)
	_downed_bar = ColorRect.new()
	_downed_bar.color = Color(1.0, 0.75, 0.2)
	_downed_bar.position = Vector2.ZERO
	_downed_bar.size = Vector2(_downed_bar_w, 14 * _ui_scale)
	frame.add_child(_downed_bar)

## A labelled bar: returns the fill ColorRect (its width is set each frame to value/max × _bar_w).
func _mk_bar(parent: Control, caption: String, fill_color: Color) -> ColorRect:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(row)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", int(14 * _ui_scale))
	cap.add_theme_color_override("font_color", UITheme.MUTED)
	cap.add_theme_color_override("font_outline_color", Color.BLACK)
	cap.add_theme_constant_override("outline_size", _OUTLINE)
	row.add_child(cap)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(_bar_w, 16 * _ui_scale)
	row.add_child(frame)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(bg)
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.position = Vector2.ZERO
	fill.size = Vector2(_bar_w, 16 * _ui_scale)
	frame.add_child(fill)
	return fill

# --- Per-frame update ----------------------------------------------------------
func _process(delta: float) -> void:
	var player := _player()
	_update_carry(player)
	_update_prompt(player)
	_update_hold_ring(player)
	_update_objective(delta)
	_update_pursuit()
	_update_survival(player, delta)
	_update_stamina_hud(player, delta)
	_update_damage_feedback(player)
	_update_damage_tick(delta)
	_update_downed(player)
	_update_hit_marker(player, delta)
	_update_notice_binding(player)

# --- Damage vignette + hit marker (task 21, FR-21-3) ---------------------------
## Watch the player's Health for a drop and flash a red vignette on damage. Under Reduce Flashing the flash
## is a low, gentle fade instead of a bright pulse (FR-21-1).
func _update_damage_feedback(player: Node) -> void:
	if player == null:
		return
	var health = player.get("health")
	if health == null:
		return
	var cur := float(health.current)
	if _last_health < 0.0:
		_last_health = cur
		return
	if cur < _last_health - 0.01:
		_flash_damage()
		_show_damage_tick(_last_health - cur)
	_last_health = cur

## Pop a floating "-N" near the health bar so a hit registers as a clear number (B2).
func _show_damage_tick(amount: float) -> void:
	if _dmg_tick_label == null:
		return
	_dmg_tick_label.text = "-%d" % int(round(amount))
	_dmg_tick_t = 1.0

func _update_damage_tick(delta: float) -> void:
	if _dmg_tick_label == null:
		return
	if _dmg_tick_t > 0.0:
		_dmg_tick_t = maxf(0.0, _dmg_tick_t - delta * 1.3)
	var peak := 0.6 if _reduce_flashing else 1.0
	_dmg_tick_label.modulate.a = _dmg_tick_t * peak
	# Float up as it fades. Anchored bottom-right (grows toward top-left), sits above the loud block.
	_dmg_tick_label.position = (Vector2(-72, -150) + Vector2(0, -26.0 * (1.0 - _dmg_tick_t))) * _ui_scale

func _flash_damage() -> void:
	if _damage_vignette == null:
		return
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	var peak := 0.12 if _reduce_flashing else 0.30
	var dur := 0.5 if _reduce_flashing else 0.35
	_damage_vignette.color.a = peak
	_vignette_tween = create_tween()
	_vignette_tween.tween_property(_damage_vignette, "color:a", 0.0, dur)

## Connect once to the player's shot_landed and briefly tint the crosshair on a confirmed hit (loud-only
## feedback, FR-21-3). Kept minimal so it never clutters the stealth read.
func _update_hit_marker(player: Node, delta: float) -> void:
	if player != _hit_player:
		_hit_player = player
		if player != null and player.has_signal("shot_landed") and not player.shot_landed.is_connected(_on_shot_landed):
			player.shot_landed.connect(_on_shot_landed)
	if _dot == null:
		return
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta * 4.0)
		_dot.add_theme_color_override("font_color", Color(1, 1, 1, 0.7).lerp(Color(1.0, 0.4, 0.3, 1.0), _hit_flash))

func _on_shot_landed() -> void:
	_hit_flash = 1.0

# --- Carry-cap rejection notice (misc-fixes-3 issue 4) -------------------------
## Follow the player's aimed interactable and listen to its local `pickup_rejected`, so a pickup refused
## by the two-axis carry cap says WHY instead of failing in silence. Lazily bound like the stamina/hit
## hooks above. Ordering is safe: interaction_target_changed is emitted synchronously as the aim changes,
## so we're connected before the same tick's hold-to-interact can fire the rejection.
func _update_notice_binding(player: Node) -> void:
	if player == _notice_src:
		return
	_notice_src = player
	if player != null and player.has_signal("interaction_target_changed") \
			and not player.interaction_target_changed.is_connected(_on_interaction_target_changed):
		player.interaction_target_changed.connect(_on_interaction_target_changed)

func _on_interaction_target_changed(interactable: Interactable) -> void:
	# is_instance_valid first: a SUCCESSFUL pickup queue_free()s the previous target, and the aim then
	# changes to null — disconnecting from a freed object would crash.
	if is_instance_valid(_reject_src) and _reject_src.pickup_rejected.is_connected(_on_pickup_rejected):
		_reject_src.pickup_rejected.disconnect(_on_pickup_rejected)
	_reject_src = null
	if interactable != null and interactable.has_signal("pickup_rejected"):
		_reject_src = interactable
		interactable.pickup_rejected.connect(_on_pickup_rejected)

func _on_pickup_rejected(axis: StringName) -> void:
	_show_notice(carry_message(axis))

## The player-facing reason a pickup was refused, by the failing carry axis. Pure. (FR-08-1 feedback)
static func carry_message(axis: StringName) -> String:
	match axis:
		&"weight":
			return "You are carrying too much weight"
		&"volume":
			return "No space — you can't carry that"
		_:
			return "Your hands are full"

## Flash a transient notice line. Auto-clears; a newer notice cancels the older clear via a token
## (the same generation-guard pattern as _on_caption).
func _show_notice(text: String) -> void:
	if _notice_label == null:
		return
	_notice_label.text = text
	_notice_token += 1
	var token := _notice_token
	var tree := get_tree()
	if tree == null:
		return
	var t := tree.create_timer(2.5)
	t.timeout.connect(func() -> void:
		if _notice_label != null and _notice_token == token:
			_notice_label.text = "")

func _update_carry(player: Node) -> void:
	if player == null or player.get("inventory") == null:
		_carry_label.text = ""
		_carry_full.text = ""
		return
	var inv = player.inventory
	var w: float = inv.current_weight()
	var v: float = inv.current_volume()
	var wc: float = inv.weight_cap
	var vc: float = inv.volume_cap
	_carry_label.text = "Weight %.1f / %.0f kg     Volume %.1f / %.0f L     In-hand $%d" % [w, wc, v, vc, inv.in_hand_value()]
	_carry_full.text = "◆ CARRY FULL — drop or bag at a Drop Point" if carry_warning(w, v, wc, vc) else ""

func _update_prompt(player: Node) -> void:
	if player != null and player.has_method("current_prompt"):
		var p: String = player.current_prompt()
		# Prefix the live bound key so the prompt stays correct after a rebind ("[F] Pick up").
		if p != "" and InputManager != null:
			_prompt_label.text = "[%s] %s" % [InputManager.primary_key_label(&"interact"), p]
		else:
			_prompt_label.text = p
	else:
		_prompt_label.text = ""

func _update_hold_ring(player: Node) -> void:
	if _hold_ring == null:
		return
	var p := 0.0
	if player != null and player.has_method("interaction_hold_progress"):
		p = float(player.interaction_hold_progress())
	_hold_ring.set_progress(p)

func _update_objective(delta: float) -> void:
	var mission := _mission()
	if mission == null:
		_objective_label.text = ""
		_secured_label.text = ""
		_escape_cue_label.text = ""
		_objective_fill.size.x = 0.0
		return
	_objective_label.text = "Objective: %s" % _objective_name(mission)
	var secured := int(mission.secured_value)
	var total := int(mission.loot_total_value()) if mission.has_method("loot_total_value") else secured
	var remaining := maxi(0, total - secured)
	_secured_label.text = "Secured $%d / $%d      Remaining $%d" % [secured, total, remaining]
	_objective_fill.size.x = _bar_w * objective_fraction(secured, total)
	_escape_cue_label.text = "◆ Objective complete — reach an Escape" if _objective_complete(mission) else ""
	# Flash the headline on a loot bank / objective tick (B3), then settle back.
	if _objective_flash > 0.0:
		_objective_flash = maxf(0.0, _objective_flash - delta * 2.0)
		_objective_label.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.6, 1.2), _objective_flash)
	else:
		_objective_label.modulate = Color(1, 1, 1, 1)

## The headline (non-escape) objective is done — reads mission.objectives_done keyed by the contract's
## objective_id (written by MissionController._on_objective_updated).
func _objective_complete(mission: Node) -> bool:
	var done = mission.get("objectives_done")
	var c = mission.get("contract")
	if done == null or c == null:
		return false
	return bool(done.get(String(c.objective_id), false))

func _update_pursuit() -> void:
	var heat := RunManager.heat if RunManager != null else 0.0
	var committed := RunManager != null and RunManager.committed
	if not committed and _phase <= 0 and heat <= 0.0:
		_pursuit_label.text = ""
		return
	_pursuit_label.text = "HEAT %.0f%%      PURSUIT phase %d" % [heat * 100.0, _phase]

## Survival block (health/armor/ammo/reload): fades in when loud/committed, Pursuit-active, damaged, OR a
## guard is actively onto the player (B1), and fades back out once that all clears (unless committed).
func _update_survival(player: Node, delta: float) -> void:
	# Drop detectors whose sensor was freed (e.g. a taken-down guard) so the block doesn't stay up for a
	# threat that no longer exists (belt-and-suspenders with DetectionSensor._exit_tree).
	for id in _actor_states.keys():
		if not is_instance_id_valid(id):
			_actor_states.erase(id)
	var committed := RunManager != null and RunManager.committed
	var health = player.get("health") if player != null else null
	var health_frac := 1.0
	if health != null and float(health.max_health) > 0.0:
		health_frac = float(health.current) / float(health.max_health)
	var detected := any_detected(_actor_states.values())
	var show := survival_visible(committed, _phase, health_frac, detected)
	_survival_alpha = move_toward(_survival_alpha, 1.0 if show else 0.0, delta * 4.0)
	_loud_box.visible = _survival_alpha > 0.01
	_loud_box.modulate.a = _survival_alpha
	if not _loud_box.visible:
		return
	_hp_fill.size.x = _bar_w * clampf(health_frac, 0.0, 1.0)
	var armor_frac := 0.0
	if health != null and health.armor != null and float(health.armor.maximum()) > 0.0:
		armor_frac = float(health.armor.current) / float(health.armor.maximum())
	_armor_fill.size.x = _bar_w * clampf(armor_frac, 0.0, 1.0)
	var weapon = player.active_weapon() if player != null and player.has_method("active_weapon") else null
	if weapon == null:
		_ammo_label.text = "UNARMED"
		_reload_row.visible = false
	elif bool(weapon.is_reloading):
		_ammo_label.text = "RELOADING…"
		_reload_row.visible = true
		_reload_fill.size.x = _bar_w * clampf(float(weapon.reload_progress()), 0.0, 1.0)
	else:
		_ammo_label.text = "AMMO %d / %d" % [int(weapon.ammo), int(weapon.reserve)]
		_reload_row.visible = false

## Stamina bar: its own fade so it appears while sprinting/dragging drains it and glides away when full.
func _update_stamina_hud(player: Node, delta: float) -> void:
	if player != _stamina_src:
		_stamina_src = player
		if player != null and player.has_signal("stamina_changed") \
				and not player.stamina_changed.is_connected(_on_stamina_changed):
			player.stamina_changed.connect(_on_stamina_changed)
		if player != null and player.get("stamina") != null:
			_stamina_cur = float(player.get("stamina"))
			_stamina_max_v = _stamina_cur   # equal → hidden until a real drain reports a max
	var show := stamina_visible(_stamina_cur, _stamina_max_v)
	_stamina_alpha = move_toward(_stamina_alpha, 1.0 if show else 0.0, delta * 4.0)
	if _stamina_box != null:
		_stamina_box.modulate.a = _stamina_alpha
	if _stamina_fill != null and _stamina_max_v > 0.0:
		_stamina_fill.size.x = _bar_w * clampf(_stamina_cur / _stamina_max_v, 0.0, 1.0)

func _on_stamina_changed(current: float, maximum: float) -> void:
	_stamina_cur = current
	_stamina_max_v = maximum

## Show the DOWNED overlay + get-up prompt + revive countdown while the player is Downed (§8.7). The
## overlay vanishing on revive is itself the "it worked" feedback the loop was missing.
func _update_downed(player: Node) -> void:
	if _downed_box == null:
		return
	var health = player.get("health") if player != null else null
	var downed := health != null and int(health.state) == Health.State.DOWNED
	_downed_box.visible = downed
	if not downed:
		return
	var key := InputManager.primary_key_label(&"interact") if InputManager != null else "F"
	_downed_prompt.text = "Press [%s] to get up" % key
	var frac := 1.0
	if health.has_method("revive_fraction"):
		frac = float(health.revive_fraction())
	_downed_bar.size.x = _downed_bar_w * clampf(frac, 0.0, 1.0)

# --- Pause (owns the `pause` action) -------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and _pause_menu == null and _player() != null:
		_open_pause()
		get_viewport().set_input_as_handled()

func _open_pause() -> void:
	var packed := load(PAUSE_SCENE) as PackedScene
	if packed == null:
		return
	_pause_menu = packed.instantiate()
	_pause_menu.tree_exited.connect(func() -> void: _pause_menu = null)
	add_child(_pause_menu)

# --- Signals / settings --------------------------------------------------------
func _on_pursuit_phase(phase: int) -> void:
	_phase = phase

## Track per-actor detection state so the survival block knows when a guard is onto the player (B1).
func _on_detection_changed(actor_id: int, state: int, _fill: float) -> void:
	if state <= 0:
		_actor_states.erase(actor_id)
	else:
		_actor_states[actor_id] = state

## Flash the objective headline on a loot bank / objective completion (B3).
func _on_loot_secured(_loot_id: String, _value: int) -> void:
	_objective_flash = 1.0

func _on_objective_updated(_objective_id: String, complete: bool) -> void:
	if complete:
		_objective_flash = 1.0

## Show a caption for a critical audio cue (FR-17-7), but only when Subtitles is enabled. Auto-clears
## after a few seconds; a newer caption cancels the older clear via a generation token.
func _on_caption(text: String) -> void:
	if _caption_label == null or not _subtitles_on():
		return
	_caption_label.text = text
	_caption_token += 1
	var token := _caption_token
	var tree := get_tree()
	if tree == null:
		return
	var t := tree.create_timer(3.0)
	t.timeout.connect(func() -> void:
		if _caption_label != null and _caption_token == token:
			_caption_label.text = "")

func _subtitles_on() -> bool:
	var s := Services.settings()
	return s != null and bool(s.get_value("audio", "subtitles"))

func _on_settings_changed(section: String) -> void:
	if section == "gameplay":
		_reduce_flashing = _read_reduce_flashing()
		var s := _read_ui_scale()
		if not is_equal_approx(s, _ui_scale):
			# UI scale changed — rebuild the HUD at the new scale (cheap; happens only on an Options change).
			_ui_scale = s
			for c in _root.get_children():
				c.queue_free()
			_compass = null
			_build()

# --- Lookups -------------------------------------------------------------------
func _player() -> Node:
	return get_tree().get_first_node_in_group(&"player") if get_tree() != null else null

func _mission() -> Node:
	return get_tree().get_first_node_in_group(&"mission_root") if get_tree() != null else null

func _objective_name(mission: Node) -> String:
	var c = mission.get("contract")
	if c == null:
		return "Reach the objective"
	var def := Content.objectives.get_def(c.objective_id) as ObjectiveDef if Content != null and Content.objectives != null else null
	return def.display_name if def != null else String(c.objective_id)

func _read_ui_scale() -> float:
	var s := Services.settings()
	return clampf(float(s.get_value("gameplay", "ui_scale")), 0.75, 1.5) if s != null else 1.0

func _read_reduce_flashing() -> bool:
	var s := Services.settings()
	return s != null and bool(s.get_value("gameplay", "reduce_flashing"))

# --- Small UI helpers ----------------------------------------------------------
func _corner_box(preset: int, offset: Vector2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(preset)
	box.position = offset
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	return box

func _mk_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", int(font_size * _ui_scale))
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", _OUTLINE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl
