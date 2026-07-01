extends GutTest
## Spec: cutting a fuse box's power disables the cameras/e-locks in its zone (only that zone), arms the
## backup-generator timer, and draws a patrol via a noise ping (FR-06-8, Phase 06.4).
## docs/tasks/06_heist_mechanics_obstacles.md, GDD §9.5.

func _hack_device(zone: StringName, device: String) -> HackTarget:
	var d := ObstacleDef.new()
	d.category = ObstacleDef.Category.HACK_TARGET
	d.power_zone = zone
	d.params = {"device": device}
	var h := HackTarget.new()
	h.def = d
	add_child_autofree(h)
	return h

func _fuse(zone: StringName) -> FuseBox:
	var d := ObstacleDef.new()
	d.category = ObstacleDef.Category.FUSE_BOX
	d.power_zone = zone
	d.backup_seconds = 20.0
	d.noise_by_solution = {"power_cut": 10.0}
	var f := FuseBox.new()
	f.def = d
	add_child_autofree(f)
	return f

func test_affects_matches_zone() -> void:
	assert_true(FuseBox.affects(&"wing_a", &"wing_a"), "same zone")
	assert_false(FuseBox.affects(&"wing_b", &"wing_a"), "different zone")
	assert_false(FuseBox.affects(&"wing_a", &""), "an empty box zone affects nothing")

func test_cut_power_disables_zone_and_draws_a_patrol() -> void:
	var elock_in := _hack_device(&"wing_a", "elock")
	var camera_in := _hack_device(&"wing_a", "camera")
	var elock_out := _hack_device(&"wing_b", "elock")
	var fuse := _fuse(&"wing_a")
	watch_signals(EventBus)

	fuse.cut_power()

	assert_true(elock_in.is_disabled(), "the in-zone e-lock loses power (opens)")
	assert_true(camera_in.is_disabled(), "the in-zone camera goes offline")
	assert_false(elock_out.is_disabled(), "a device in another zone is untouched")
	assert_true(fuse.backup_active, "the backup generator timer is armed")
	assert_almost_eq(fuse.backup_remaining, 20.0, 0.0001, "timer starts at backup_seconds")
	assert_signal_emitted(EventBus, "noise_emitted", "the outage draws a patrol to investigate")
