extends GutTest
## Task 17 (FR-17-4): the Options audio sliders set the right AudioServer bus dB via SettingsManager,
## the Ambience bus resolves, and muting (0.0) floors the bus. docs/tasks/17_audio.md.

func after_each() -> void:
	# Restore the schema defaults so later tests see a normal mix.
	SettingsManager.set_value("audio", "master", 1.0)
	SettingsManager.set_value("audio", "music", 0.8)
	SettingsManager.set_value("audio", "sfx", 0.9)
	SettingsManager.set_value("audio", "ambience", 0.7)

func test_all_five_buses_exist() -> void:
	for bus in ["Master", "Music", "SFX", "UI", "Ambience"]:
		assert_true(AudioServer.get_bus_index(bus) >= 0, "bus '%s' exists (Ambience was added by task 17)" % bus)

func test_slider_sets_bus_db() -> void:
	SettingsManager.set_value("audio", "music", 0.5)
	var idx := AudioServer.get_bus_index("Music")
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), linear_to_db(0.5), 0.05)

func test_ambience_slider_is_live() -> void:
	SettingsManager.set_value("audio", "ambience", 0.25)
	var idx := AudioServer.get_bus_index("Ambience")
	assert_almost_eq(AudioServer.get_bus_volume_db(idx), linear_to_db(0.25), 0.05)

func test_mute_floors_the_bus() -> void:
	SettingsManager.set_value("audio", "sfx", 0.0)
	var idx := AudioServer.get_bus_index("SFX")
	# 0.0 is clamped to 0.0001 linear → about -80 dB (silence), never -inf.
	assert_lt(AudioServer.get_bus_volume_db(idx), -40.0, "muted bus is floored")
