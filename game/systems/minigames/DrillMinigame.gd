extends Minigame
class_name DrillMinigame
## Drill / thermite overlay (FR-07-8, GDD §9.6/§9.8): NOT a puzzle — a TENSION MANAGER. It drives a
## BreachPoint (the timer + jam + noise maths already live there, tasks 06) and shows the progress
## gauge; when the drill JAMS, press to repair and resume. NON-MODAL (pauses_world = false) so guards
## keep closing in while it grinds — and the drill deliberately KEEPS RUNNING while you walk off to
## deal with them. Only the JAM repair is proximity-gated: you must come back to the door, roughly as
## close as you had to be to start the breach. Solves when the barrier is breached.
## See docs/tasks/07_minigames.md.

var _breach: BreachPoint
var _method: StringName = &"drill"
var _fraction: float = 0.0
var _jammed: bool = false
var _readout: Label
var _driller: Node3D   ## the player working the drill; a jam can only be cleared from AT the breach

func _init() -> void:
	pauses_world = false   # the drill draws guards — the world must keep running (GDD §9.6)

# --- Lifecycle -------------------------------------------------------------
func begin(ctx: Dictionary = {}) -> void:
	super.begin(ctx)
	_breach = ctx.get("breach") as BreachPoint
	_method = StringName(ctx.get("method", &"drill"))
	_driller = ctx.get("hacker") as Node3D   # MinigameHost injects the player under this key
	if _driller == null and is_inside_tree():
		_driller = get_tree().get_first_node_in_group(&"player") as Node3D
	if _breach == null:
		abort()   # nothing to drive
		return
	_breach.breach_progress.connect(_on_progress)
	_breach.jammed.connect(_on_jammed)
	_breach.breached.connect(_on_breached)
	_breach.equip_tool(ctx.get("breach_gear", {}))   # apply the loadout breach tool's upgrades (task 09)
	_build_ui()
	# (This used to pass ctx["by"] — a key MinigameHost._build_ctx never injects, so it was always null.)
	_breach.begin_breach(_method, _driller)

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # offsets too: anchors alone keep the 0x0 rect a code-built Control starts with
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout = Label.new()
	_readout.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_readout.grow_horizontal = Control.GROW_DIRECTION_BOTH   # else the label's LEFT edge sits at centre
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.position.y = 40.0
	add_child(_readout)
	_refresh()

func _on_progress(fraction: float) -> void:
	_fraction = fraction
	_refresh()

func _on_jammed() -> void:
	_jammed = true
	_refresh()

func _on_breached(_method: StringName) -> void:
	_finish_solved()

func _process(_delta: float) -> void:
	if _finished or _breach == null:
		return
	if _jammed and Input.is_action_just_pressed(&"ui_accept") and _can_reach_drill():
		_breach.repair()
		_jammed = _breach.is_jammed
		_refresh()

## You must be AT the breach to free a jam — clearing it from across the map was the bug (issue 2).
## Reuses HackMinigame's already-unit-tested proximity seam rather than a local copy. With no spatial
## context (headless test / greybox with no player), the drill stays operable.
func _can_reach_drill() -> bool:
	if _driller == null or _breach == null:
		return true
	return HackMinigame.in_proximity(
		_driller.global_position.distance_to(_breach.global_position), config.drill_proximity_range)

func _refresh() -> void:
	if _readout == null:
		return
	const CELLS := 20
	var filled := int(round(_fraction * CELLS))
	var bar := "#".repeat(filled) + "-".repeat(CELLS - filled)
	var line := "DRILL  %s  [%s] %d%%" % [String(_method).to_upper(), bar, int(round(_fraction * 100.0))]
	if _jammed:
		line += "\n!! JAMMED — [Enter] to clear (stand at the drill) !!"
		if not _can_reach_drill():
			line += "\n— TOO FAR FROM THE DRILL —"
	_readout.text = line
