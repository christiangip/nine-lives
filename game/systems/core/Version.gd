extends RefCounted
class_name Version
## Build / version stamp (task 21, FR-21-7). The single source of truth is
## project.godot → application/config/version (bumped to 1.0.0 for the M5 base-game release); this surfaces
## it to the Main Menu, the Pause menu, and the release checklist. A static helper, not an 11th autoload.
## A CI/build step can also stamp build metadata (commit/date) via the optional override below.
## See docs/RELEASE_CHECKLIST.md and docs/tasks/21_release_polish.md.

const CODENAME := "Nine Lives"

## Optional build metadata a release/CI step can set (e.g. "rc1", a short commit, a date). Empty in dev.
static var build_metadata: String = ""

## The semantic version from ProjectSettings, e.g. "1.0.0".
static func number() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## A display stamp: "Nine Lives v1.0.0" (+ "+meta" when build_metadata is set).
static func string() -> String:
	var v := "%s v%s" % [CODENAME, number()]
	return "%s+%s" % [v, build_metadata] if build_metadata != "" else v
