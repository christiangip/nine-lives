extends RefCounted
class_name MissionValidator
## Solvability + integrity proof for a MissionLayout (task 11, FR-11-3, consumes FR-06-10). Pure/static
## so it gates CI headlessly. `validate()` proves a stealth-viable path entry → objective → escape plus
## a reachable Drop Point, by BFS over the section graph with a **key/clue fix-point**: a gated edge is
## passable only via a stealth solution that is actually available (a skill minigame / avoid, OR a found
## key/clue that is itself reachable earlier). It also refuses any non-LOCK obstacle that is
## minigame-only (the GDD forbids it). This is a genuine check, not a rubber stamp — mis-placing the
## vault key behind its own door makes it return false. See docs/tasks/11_mission_generation.md.

## Always-available stealth solutions: the skill minigames (host runs them with zero gear) + free routes.
const UNIVERSAL: Array[StringName] = [&"lockpick", &"safe_dial", &"hack", &"keypad", &"pickpocket", &"avoid"]
## Need the gate's required_item to be a reachable found-key first.
const ITEM_SOLUTIONS: Array[StringName] = [&"keycard", &"key", &"clone"]
## Need the gate's clue_id to be a reachable found-clue first.
const CLUE_SOLUTIONS: Array[StringName] = [&"found_combo", &"found_code"]

static func validate(layout: MissionLayout) -> bool:
	if layout == null or layout.sections.is_empty():
		return false
	if layout.entry_indices().is_empty():
		return false
	if layout.objective_index < 0 or layout.escape_index < 0:
		return false
	if not no_overlap(layout):
		return false
	# FR-06-10: never a non-LOCK minigame-only gate (would strand players without the one tool).
	for g in layout.gates:
		if bool(g.get("minigame_only", false)) and int(g.get("category", -1)) != ObstacleDef.Category.LOCK:
			return false
	var reachable := reachable_sections(layout)
	if not reachable.has(layout.objective_index):
		return false
	if not reachable.has(layout.escape_index):
		return false
	return _any_reachable(layout.drop_points, reachable)

## Set (Dictionary index->true) of sections reachable from the entries, with a key/clue fix-point.
static func reachable_sections(layout: MissionLayout) -> Dictionary:
	var reachable: Dictionary = {}
	for e in layout.entry_indices():
		reachable[e] = true
	var found_items: Dictionary = {}
	var found_clues: Dictionary = {}
	var changed := true
	while changed:
		changed = false
		for k in layout.keys:
			if reachable.has(k.get("section", -1)) and not found_items.has(k.get("item_id")):
				found_items[k.get("item_id")] = true
				changed = true
		for c in layout.clues:
			if reachable.has(c.get("section", -1)) and not found_clues.has(c.get("clue_id")):
				found_clues[c.get("clue_id")] = true
				changed = true
		for edge in layout.edges:
			var a: int = edge.a
			var b: int = edge.b
			var a_r := reachable.has(a)
			var b_r := reachable.has(b)
			if a_r == b_r:
				continue
			var dst: int = b if a_r else a
			if _edge_passable(layout, edge, found_items, found_clues):
				reachable[dst] = true
				changed = true
	return reachable

static func _edge_passable(layout: MissionLayout, edge: Dictionary, found_items: Dictionary, found_clues: Dictionary) -> bool:
	var gate_i: int = edge.get("gate", -1)
	if gate_i < 0:
		return true   # open connection
	var g: Dictionary = layout.gates[gate_i]
	for s in g.get("solutions", []):
		var sol := StringName(s)
		if sol in UNIVERSAL:
			return true
		elif sol in ITEM_SOLUTIONS:
			if found_items.has(g.get("required_item")):
				return true
		elif sol in CLUE_SOLUTIONS:
			if found_clues.has(g.get("clue_id")):
				return true
	return false

## No two sections share a grid cell, and no section exceeds its declared socket count (FR-11-2).
static func no_overlap(layout: MissionLayout) -> bool:
	var seen: Dictionary = {}
	for ps in layout.sections:
		for c in ps.cells():
			if seen.has(c):
				return false
			seen[c] = true
	for ps in layout.sections:
		if ps.sockets_used > ps.def.socket_count:
			return false
	return true

static func _any_reachable(rows: Array, reachable: Dictionary) -> bool:
	for r in rows:
		if reachable.has(r.get("section", -1)):
			return true
	return false
