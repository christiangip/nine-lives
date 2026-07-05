extends GutTest
## Task 16 (FR-16-8): saves are written atomically (tmp + rename), so an interrupted write / leftover
## temp file never corrupts the previous save. docs/tasks/16_save_system.md.

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(SaveManager.SAVE_DIR)
	GameManager.active_slot = 0
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func after_each() -> void:
	TestHelper.rm_dir(SaveManager.SAVE_DIR)
	ProgressionManager.from_dict({})
	RunManager.from_dict({})

func test_save_leaves_no_temp_file() -> void:
	assert_true(SaveManager.save_slot(0), "save succeeds")
	assert_false(FileAccess.file_exists("%s/slot_0.json.tmp" % SaveManager.SAVE_DIR), "temp file swapped away")
	assert_true(FileAccess.file_exists("%s/slot_0.json" % SaveManager.SAVE_DIR), "real save written")

func test_interrupted_write_leaves_previous_intact() -> void:
	ProgressionManager.legacy = 1234
	SaveManager.save_slot(0)
	# Simulate an interrupted write: a half-written garbage .tmp left beside the good file.
	var tmp := "%s/slot_0.json.tmp" % SaveManager.SAVE_DIR
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string("{ broken json")
	f.close()

	assert_true(SaveManager.scan_slots()[0], "slot still reads as populated (tmp is ignored)")
	ProgressionManager.from_dict({})
	assert_true(SaveManager.load_slot(0), "the previous save still loads")
	assert_eq(ProgressionManager.legacy, 1234, "previous state is intact")

func test_corrupt_slot_reads_as_empty() -> void:
	var f := FileAccess.open("%s/slot_3.json" % SaveManager.SAVE_DIR, FileAccess.WRITE)
	f.store_string("not json at all")
	f.close()
	assert_false(SaveManager.scan_slots()[3], "a corrupt file is not counted as a valid slot")
	assert_true(SaveManager.slot_summary(3).is_empty(), "corrupt slot summary is empty")
	assert_false(SaveManager.load_slot(3), "corrupt slot fails to load")
