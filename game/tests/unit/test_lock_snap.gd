extends GutTest
## Spec: a failed pick attempt can SNAP a consumable pick, and the Lockpicking attribute lowers the
## snap odds (FR-06-1, Phase 06.1). docs/tasks/06_heist_mechanics_obstacles.md, GDD §9.1.

func _lock() -> Lock:
	var d := ObstacleDef.new()
	d.id = &"test_lock"
	d.category = ObstacleDef.Category.LOCK
	d.snap_base_chance = 0.25
	var lock := Lock.new()
	lock.def = d
	add_child_autofree(lock)
	return lock

func test_snap_chance_drops_with_lockpicking() -> void:
	assert_almost_eq(Lock.snap_chance(0.25, 0.0, 0.03), 0.25, 0.0001, "base chance with no skill")
	assert_almost_eq(Lock.snap_chance(0.25, 5.0, 0.03), 0.10, 0.0001, "five levels shave 0.15 off")
	assert_almost_eq(Lock.snap_chance(0.10, 10.0, 0.03), 0.0, 0.0001, "clamped at zero, never negative")

func test_should_snap_threshold() -> void:
	assert_true(Lock.should_snap(0.05, 0.25), "a roll under the chance snaps")
	assert_false(Lock.should_snap(0.50, 0.25), "a roll over the chance holds")

func test_failed_attempt_snaps_and_consumes_a_pick() -> void:
	var lock := _lock()
	var pouch := PickPouch.new(3)
	lock.set_pouch(pouch)
	watch_signals(lock)
	lock.resolve_attempt(false, 0.01)   # forced low roll => snaps at the 0.25 base chance
	assert_eq(pouch.count, 2, "a snapped pick is consumed")
	assert_signal_emitted(lock, "pick_snapped")
	assert_false(lock.solved, "a failed attempt does not open the lock")

func test_failed_attempt_without_snap_keeps_the_pick() -> void:
	var lock := _lock()
	var pouch := PickPouch.new(3)
	lock.set_pouch(pouch)
	lock.resolve_attempt(false, 0.99)   # high roll => no snap
	assert_eq(pouch.count, 3, "no snap, no pick lost")
	assert_false(lock.solved)

func test_success_opens_without_consuming() -> void:
	var lock := _lock()
	var pouch := PickPouch.new(3)
	lock.set_pouch(pouch)
	watch_signals(lock)
	lock.resolve_attempt(true)
	assert_true(lock.solved, "a solved minigame opens the lock")
	assert_eq(pouch.count, 3, "success costs no pick")
	assert_signal_emitted(lock, "obstacle_solved")
