extends Minigame
class_name DrillMinigame
## Drill / thermite overlay (FR-07-8, GDD §9.6/§9.8): NOT a puzzle — a TENSION MANAGER. It drives a
## BreachPoint (the timer + jam + noise maths already live there, tasks 06) and shows the progress
## gauge; when the drill JAMS, press to repair and resume. NON-MODAL (pauses_world = false) so guards
## keep closing in while it grinds. Solves when the barrier is breached. See docs/tasks/07_minigames.md.

var _breach: BreachPoint
var _method: StringName = &"drill"
var _fraction: float = 0.0
var _jammed: bool = false
var _readout: Label

func _init() -> void:
	pauses_world = false   # the drill draws guards — the world must keep running (GDD §9.6)

# --- Lifecycle -------------------------------------------------------------
func begin(ctx: Dictionary = {}) -> void:
	super.begin(ctx)
	_breach = ctx.get("breach") as BreachPoint
	_method = StringName(ctx.get("method", &"drill"))
	if _breach == null:
		abort()   # nothing to drive
		return
	_breach.breach_progress.connect(_on_progress)
	_breach.jammed.connect(_on_jammed)
	_breach.breached.connect(_on_breached)
	_breach.equip_tool(ctx.get("breach_gear", {}))   # apply the loadout breach tool's upgrades (task 09)
	_build_ui()
	_breach.begin_breach(_method, ctx.get("by"))

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout = Label.new()
	_readout.set_anchors_preset(Control.PRESET_CENTER_TOP)
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
	if _jammed and Input.is_action_just_pressed(&"ui_accept"):
		_breach.repair()
		_jammed = _breach.is_jammed
		_refresh()

func _refresh() -> void:
	if _readout == null:
		return
	const CELLS := 20
	var filled := int(round(_fraction * CELLS))
	var bar := "#".repeat(filled) + "-".repeat(CELLS - filled)
	var line := "DRILL  %s  [%s] %d%%" % [String(_method).to_upper(), bar, int(round(_fraction * 100.0))]
	if _jammed:
		line += "\n!! JAMMED — [Enter] to clear !!"
	_readout.text = line
