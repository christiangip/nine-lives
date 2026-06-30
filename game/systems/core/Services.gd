extends RefCounted
class_name Services
## Lightweight service locator — one seam for reaching the autoload managers and the
## content hub, so call sites (and managers) avoid hard-coded sideways references and
## uphold the dependency rule (ARCHITECTURE.md). Pure static; never instantiated.
## Returns are typed `Node` because autoloads carry no class_name.
## See docs/tasks/02_core_architecture.md.

static func _autoload(autoload_name: StringName) -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath(autoload_name))
	return null

static func content() -> Node:
	return _autoload(&"Content")

static func game() -> Node:
	return _autoload(&"GameManager")

static func progression() -> Node:
	return _autoload(&"ProgressionManager")

static func run() -> Node:
	return _autoload(&"RunManager")

static func save() -> Node:
	return _autoload(&"SaveManager")

static func missions() -> Node:
	return _autoload(&"MissionGenerator")

static func audio() -> Node:
	return _autoload(&"AudioManager")

static func settings() -> Node:
	return _autoload(&"SettingsManager")
