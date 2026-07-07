extends GutTest
## Task 21 FR-21-2: the AI performance budget (the deferred 05.5 work). Pure LOD seams — the per-distance
## sense interval and the round-robin stagger — plus the mission-population guard cap that keeps a dense scene
## inside the instance/AI budget. The real FPS measurement is the manual pass in docs/PERFORMANCE.md; these
## lock the enforceable logic. See docs/tasks/21_release_polish.md.

func _cfg() -> DetectionConfigDef:
	var c := DetectionConfigDef.new()
	c.lod_full_range = 20.0
	c.lod_mid_range = 40.0
	c.lod_sleep_range = 70.0
	c.lod_mid_interval = 2
	c.lod_far_interval = 4
	return c

# --- LOD sense interval by distance ----------------------------------------
func test_near_guards_sense_every_frame() -> void:
	var c := _cfg()
	assert_eq(DetectionSensor.sense_interval_for_distance(0.0, c), 1, "point blank → every frame")
	assert_eq(DetectionSensor.sense_interval_for_distance(20.0, c), 1, "at the full-range edge → every frame")

func test_mid_and_far_guards_are_throttled() -> void:
	var c := _cfg()
	assert_eq(DetectionSensor.sense_interval_for_distance(30.0, c), 2, "mid range → mid interval")
	assert_eq(DetectionSensor.sense_interval_for_distance(55.0, c), 4, "far range → far interval")

func test_very_distant_guards_sleep() -> void:
	assert_eq(DetectionSensor.sense_interval_for_distance(100.0, _cfg()), 0, "beyond the sleep range → sleep (0)")

func test_null_config_is_safe() -> void:
	assert_eq(DetectionSensor.sense_interval_for_distance(5.0, null), 1, "no config → every frame (safe default)")

# --- Round-robin stagger ---------------------------------------------------
func test_interval_one_always_senses() -> void:
	for f in 5:
		assert_true(DetectionSensor.should_sense(f, 0, 1), "interval 1 senses every frame")

func test_each_sensor_senses_once_per_interval() -> void:
	var interval := 4
	for phase in interval:
		var hits := 0
		for f in interval:
			if DetectionSensor.should_sense(f, phase, interval):
				hits += 1
		assert_eq(hits, 1, "phase %d senses exactly once per %d-frame window" % [phase, interval])

func test_phases_stagger_across_frames() -> void:
	# At any single frame, only one of the `interval` phases senses — load is spread, not bunched.
	var interval := 4
	var frame := 100
	var firing := 0
	for phase in interval:
		if DetectionSensor.should_sense(frame, phase, interval):
			firing += 1
	assert_eq(firing, 1, "at a given frame only one of the %d staggered phases senses" % interval)

# --- Population cap ---------------------------------------------------------
func test_population_respects_the_guard_cap() -> void:
	var ai := Content.ai.get_def(&"default") as AIConfigDef
	assert_not_null(ai, "the default AI config is registered")
	var orig := ai.max_active_guards
	ai.max_active_guards = 3   # force the cap to bite even on a stress mission
	var c := Contract.new()
	c.archetype_id = &"bank"
	c.objective_id = &"grab_value"
	c.mission_seed = 7
	c.tier = 4
	c.difficulty = 5
	var layout := MissionGenerator.generate_layout(c)
	ai.max_active_guards = orig   # restore the shared resource before asserting
	var patrols := 0
	for a in layout.actors:
		if StringName(a.get("carried_item", &"")) == &"":
			patrols += 1
	assert_true(patrols <= 3, "patrol guards never exceed max_active_guards (got %d)" % patrols)
