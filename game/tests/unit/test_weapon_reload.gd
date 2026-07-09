extends GutTest
## Part A: Weapon now reloads over time (reload_time) from a finite reserve, and can't fire mid-reload.
## This gives guards sustained fire (they reload between bursts instead of being disarmed after one mag)
## and the HUD a reload_progress() to show. Locks the timed-reload seam. See bug-fixes-ui-overhaul.md Part A.

func _make_weapon(capacity: int, reserve: int, reload_time: float) -> Weapon:
	var gd := GearDef.new()
	gd.id = &"test_gun"
	gd.params = {
		"damage": 10.0, "ammo_capacity": capacity, "reserve": reserve,
		"reload_time": reload_time, "fire_interval": 0.0,
	}
	return Weapon.new(gd)

func test_reads_reserve_and_starts_full_mag() -> void:
	var w := _make_weapon(12, 24, 1.5)
	assert_eq(w.ammo, 12, "spawns with a full magazine")
	assert_eq(w.reserve, 24, "reserve is read from the def params")

func test_reload_is_timed_not_instant() -> void:
	var w := _make_weapon(12, 24, 1.5)
	for i in 12:
		w.fire()
	assert_eq(w.ammo, 0, "magazine emptied")
	assert_false(w.can_fire(), "can't fire on an empty mag")
	assert_true(w.reload(), "reload starts")
	assert_true(w.is_reloading, "reload is in progress")
	assert_false(w.can_fire(), "can't fire mid-reload")
	assert_almost_eq(w.reload_progress(), 0.0, 0.01, "progress starts at 0")
	w.tick(0.75)
	assert_almost_eq(w.reload_progress(), 0.5, 0.05, "progress tracks halfway through the reload time")
	assert_eq(w.ammo, 0, "rounds aren't loaded until the reload completes")
	w.tick(0.8)   # past the 1.5s reload
	assert_false(w.is_reloading, "reload completes")
	assert_eq(w.ammo, 12, "the magazine refills from reserve")
	assert_eq(w.reserve, 12, "reserve is drawn down by the rounds loaded")
	assert_true(w.can_fire(), "can fire again after the reload")

func test_reload_noop_with_empty_reserve() -> void:
	var w := _make_weapon(12, 0, 1.5)
	w.fire()
	assert_false(w.reload(), "no reserve → nothing to reload")
	assert_false(w.is_reloading, "no reload started")
