extends Node3D
class_name NoiseRingSpawner
## The on-world noise-ring readout (task 15, FR-15-5). A mission-scoped Node3D that listens to the frozen
## EventBus.noise_emitted(position, radius, source) and spawns a translucent ring at the source that
## expands to `radius` and fades — the diegetic "you just made a sound this big" cue that keeps FP stealth
## legible (Q1). Footsteps read cyan, gunshots red. Honours gameplay/reduce_flashing (a single smooth
## expand+fade, never a strobe). No gameplay logic; purely presentational. See docs/tasks/15_ui_hud_menus.md.

const EXPAND_TIME := 0.55
const RING_HEIGHT := 0.12       ## sits just above the floor

func _ready() -> void:
	if not EventBus.noise_emitted.is_connected(_on_noise_emitted):
		EventBus.noise_emitted.connect(_on_noise_emitted)

func _on_noise_emitted(position: Vector3, radius: float, source: String) -> void:
	if radius <= 0.0 or not is_inside_tree():
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0     ## unit ring; scaled up to `radius` by the tween
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.35, 0.30, 0.7) if source == "gunshot" else Color(0.35, 0.85, 0.95, 0.6)
	ring.material_override = mat
	add_child(ring)
	ring.global_position = position + Vector3(0.0, RING_HEIGHT, 0.0)
	var full := Vector3.ONE * maxf(0.3, radius)
	var start: Color = mat.albedo_color
	var faded := Color(start.r, start.g, start.b, 0.0)

	if reduce_flashing():
		# Reduce Flashing (FR-21-1): the ring appears at full size and only fades — no expanding pulse.
		ring.scale = full
		var tw := create_tween()
		tw.tween_property(mat, "albedo_color", faded, EXPAND_TIME)
		tw.tween_callback(ring.queue_free)
		return

	ring.scale = Vector3.ONE * 0.2
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", full, EXPAND_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color", faded, EXPAND_TIME)
	tween.chain().tween_callback(ring.queue_free)

## The Reduce Flashing accessibility option (gameplay/reduce_flashing); false without SettingsManager.
func reduce_flashing() -> bool:
	var s := Services.settings()
	return s != null and bool(s.get_value("gameplay", "reduce_flashing"))
