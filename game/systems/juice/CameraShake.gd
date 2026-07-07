extends RefCounted
class_name CameraShake
## Trauma-based first-person camera shake (task 21 — FR-21-3 juice + the FR-21-1 accessibility toggle). Owned
## and ticked by PlayerController; add_trauma() is called on fire/damage/alarm. Shake magnitude is trauma²
## (so small traumas barely register and large ones decay smoothly), applied as a small additive rotation +
## projection offset on the FP Camera3D — it never touches the Head's lean/pitch, so it can't fight look. The
## caller gates it OFF when video/camera_shake is false OR gameplay/reduce_flashing is true. Pure seams
## (shake_magnitude / decay) are unit-tested. No magic numbers — amplitudes are injected from PlayerConfigDef.
## See docs/tasks/21_release_polish.md and GDD §15.2.

var trauma: float = 0.0
var max_trauma: float = 1.0
var decay_per_sec: float = 1.6
var max_angle_rad: float = deg_to_rad(2.5)
var max_offset: float = 0.08
var _t: float = 0.0

## Add trauma (clamped). Callers scale by the event (a gunshot < taking a hit).
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, max_trauma)

## Advance one frame and return the additive camera offset: {rot: Vector3(pitch,yaw,roll), ofs: Vector2(h,v)}.
## Deterministic layered-sine pseudo-noise (no RNG) so it's smooth and reproducible.
func tick(delta: float) -> Dictionary:
	_t += delta
	trauma = decay(trauma, decay_per_sec, delta)
	var m := shake_magnitude(trauma)
	if m <= 0.0:
		return {"rot": Vector3.ZERO, "ofs": Vector2.ZERO}
	var rot := Vector3(
		max_angle_rad * m * _noise(11.0, 0.13),
		max_angle_rad * m * _noise(13.0, 5.70),
		max_angle_rad * m * 0.6 * _noise(17.0, 2.10))
	var ofs := Vector2(max_offset * m * _noise(19.0, 8.30), max_offset * m * _noise(23.0, 1.20))
	return {"rot": rot, "ofs": ofs}

func _noise(freq: float, phase: float) -> float:
	return sin(_t * freq + phase) * cos(_t * freq * 0.37 + phase * 1.7)

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Shake amount from trauma (quadratic falloff so small traumas fade fast). Pure.
static func shake_magnitude(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c

## Trauma after `dt` of linear decay at `rate`/sec, clamped to 0..1. Pure.
static func decay(t: float, rate: float, dt: float) -> float:
	return clampf(t - rate * dt, 0.0, 1.0)
