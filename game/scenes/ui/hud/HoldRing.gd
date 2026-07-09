extends Control
class_name HoldRing
## A tiny radial hold-to-interact progress ring drawn around the crosshair (task Part B / FR-15-6).
## Interactions with a hold time expose their progress via PlayerController.interaction_hold_progress();
## the HUD feeds it here as `progress` (0..1) and the ring fills clockwise from the top. Hidden at 0 so
## a tap interaction (no hold) draws nothing. Mouse-transparent like every HUD element. Built in code.

const _RADIUS := 22.0
const _WIDTH := 5.0

var progress: float = 0.0        ## 0..1; set by the HUD each frame

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_RADIUS * 2.0 + 8.0, _RADIUS * 2.0 + 8.0)

## Set the fill and redraw only when it actually changed (cheap; avoids a redraw every idle frame).
func set_progress(p: float) -> void:
	var v := clampf(p, 0.0, 1.0)
	if is_equal_approx(v, progress):
		return
	progress = v
	queue_redraw()

func _draw() -> void:
	if progress <= 0.0:
		return
	var center := size * 0.5
	# Faint track + a bright arc that sweeps clockwise from 12 o'clock as the hold completes.
	draw_arc(center, _RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.15), _WIDTH)
	var start := -PI * 0.5
	draw_arc(center, _RADIUS, start, start + TAU * progress, 48, UITheme.ACCENT, _WIDTH)
