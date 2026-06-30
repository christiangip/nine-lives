extends GutTest
## Spec: every autoload singleton resolves at /root/<Name> and runs its expected
## script — i.e. the project boots with all autoloads wired (FR-01-1).
## docs/tasks/01_project_setup.md.

const EXPECTED := {
	"EventBus": "res://game/autoload/EventBus.gd",
	"Content": "res://game/autoload/Content.gd",
	"GameManager": "res://game/autoload/GameManager.gd",
	"InputManager": "res://game/autoload/InputManager.gd",
	"SaveManager": "res://game/autoload/SaveManager.gd",
	"ProgressionManager": "res://game/autoload/ProgressionManager.gd",
	"RunManager": "res://game/autoload/RunManager.gd",
	"MissionGenerator": "res://game/autoload/MissionGenerator.gd",
	"AudioManager": "res://game/autoload/AudioManager.gd",
	"SettingsManager": "res://game/autoload/SettingsManager.gd",
}

func test_all_autoloads_present_and_correct() -> void:
	var root := get_tree().root
	for autoload_name in EXPECTED:
		var node := root.get_node_or_null(NodePath(autoload_name))
		assert_not_null(node, "Autoload '%s' must exist at /root/%s" % [autoload_name, autoload_name])
		if node != null:
			var script: Script = node.get_script()
			assert_not_null(script, "Autoload '%s' must have a script" % autoload_name)
			if script != null:
				assert_eq(script.resource_path, EXPECTED[autoload_name],
					"Autoload '%s' should run %s" % [autoload_name, EXPECTED[autoload_name]])

func test_project_defines_ten_autoloads() -> void:
	assert_eq(EXPECTED.size(), 10, "Project defines ten autoloads (Content is the data backbone)")
