extends GutTest
## Task 13 (FR-13-4): the Training station front-end drives ProgressionManager.train_attribute — spends
## Legacy and raises the attribute level, and the preview cost the station shows matches what's spent.
## (The attribute maths itself is task 12; this asserts the station's use of it stays honest.)

func before_each() -> void:
	ProgressionManager.legacy = 0
	ProgressionManager.attributes.clear()

func test_training_spends_legacy_and_raises_the_attribute() -> void:
	var def := Content.attributes.get_def(&"lockpicking") as AttributeDef
	assert_not_null(def, "the attribute exists as data")
	var preview := ProgressionManager.attribute_cost(def, ProgressionManager.attribute_level(&"lockpicking"))
	assert_gt(preview, 0, "the station can preview the next-level cost")
	ProgressionManager.legacy = preview
	assert_true(ProgressionManager.train_attribute(&"lockpicking"), "affordable → trains")
	assert_eq(ProgressionManager.attribute_level(&"lockpicking"), 1, "the level rose by one")
	assert_eq(ProgressionManager.legacy, 0, "the previewed cost is exactly what was spent")

func test_training_blocked_without_legacy() -> void:
	ProgressionManager.legacy = 0
	assert_false(ProgressionManager.train_attribute(&"lockpicking"), "broke → no training")
	assert_eq(ProgressionManager.attribute_level(&"lockpicking"), 0, "no level gained")
