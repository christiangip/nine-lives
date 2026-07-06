@tool
extends EditorScript
## In-editor content validator (task 19, FR-19-3). File ▸ Run this script to check content structure —
## id present/unique/lowercase_snake, required fields, and dangling cross-references — against a freshly
## scanned Content (including any enabled packs). Prints to the Output panel. Game autoloads don't run in
## the editor, so this builds a transient Content and validates that; the full sweep (incl. economy-range
## checks) runs headlessly via tools/scripts/validate_content.sh, which is also the CI gate.

func _run() -> void:
	var content_script: GDScript = load("res://game/autoload/Content.gd")
	var c: Node = content_script.new()
	c._build()
	c.scan_all()
	var errors: Array = ContentValidator.validate_content(c)
	c.free()
	if errors.is_empty():
		print("[content-validate] structural checks OK — run tools/scripts/validate_content.sh for the full sweep (incl. economy ranges).")
		return
	push_warning("[content-validate] %d structural violation(s) — see below." % errors.size())
	for e in errors:
		print("  - %s" % e)
