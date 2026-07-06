extends SceneTree
## Headless content-validation entry point (task 19, FR-19-3). Run via:
##   godot --headless -s tools/godot/ContentValidateMain.gd   (see tools/scripts/validate_content.sh)
## Waits for the autoloads to settle, runs ContentValidator.validate() (structural + economy ranges over
## the base game + any enabled packs), prints every violation, and exits non-zero if any — so CI fails on
## malformed content. See docs/tasks/19_expansion_framework.md and docs/AUTHORING.md.

func _init() -> void:
	_run()

func _run() -> void:
	# Two frames so every autoload (_ready → Content scan) has finished before we validate.
	await process_frame
	await process_frame
	var errors: Array = ContentValidator.validate()
	if errors.is_empty():
		print("[content-validate] OK — all content tables valid.")
		quit(0)
	else:
		print("[content-validate] FAILED — %d violation(s):" % errors.size())
		for e in errors:
			print("  - %s" % e)
		quit(1)
