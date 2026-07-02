extends RefCounted
class_name MissionLayout
## The abstract, seed-reproducible mission model (task 11) — the output of assemble() + populate(),
## validated by MissionValidator, and *realized* into a Node3D tree by MissionGenerator.build().
## Pure data (no scene instancing) so layout + solvability + reproducibility all test headlessly.
## Everything here is plain Dictionaries/arrays keyed by content id, so to_dict() is a faithful,
## deterministic fingerprint (same seed → identical dict). See docs/tasks/11_mission_generation.md.

const CELL_SIZE := 6.0   ## metres per grid cell (realize-time scale; keeps anchors in cell units)

# --- Header ----------------------------------------------------------------
var archetype_id: StringName = &""
var mission_seed: int = 0
var tier: int = 1
var difficulty: int = 1
var objective_kind: int = 0            ## ObjectiveDef.Kind of the headline objective
var objective_id: StringName = &""
var modifier_ids: Array[StringName] = []

# --- Topology --------------------------------------------------------------
var sections: Array[PlacedSection] = []
var edges: Array[Dictionary] = []      ## {a:int, b:int, gate:int}  (gate = index into `gates`, or -1)
var gates: Array[Dictionary] = []      ## flattened obstacle data (see MissionPopulator._make_gate)
var entry_index: int = -1
var objective_index: int = -1
var escape_index: int = -1
var objective_data: Dictionary = {}    ## headline objective placement (kind/section/mark_section/loot_id…)

# --- Population (all {..., section:int, pos:Vector3}) -----------------------
var loot: Array[Dictionary] = []
var actors: Array[Dictionary] = []
var civilians: Array[Dictionary] = []
var consumables: Array[Dictionary] = []
var keys: Array[Dictionary] = []       ## found items that unlock gates {item_id, section}
var clues: Array[Dictionary] = []      ## found combos/codes {clue_id, section}
var hazards: Array[Dictionary] = []    ## in-room cameras/lasers/alarms (not traversal gates)
var drop_points: Array[Dictionary] = []
var reinforce_points: Array[Dictionary] = []
var entry_points: Array[Dictionary] = []

# --- Transient assembly state (NOT serialized) -----------------------------
var occupied: Dictionary = {}          ## Vector2i cell -> section index

func add_section(ps: PlacedSection) -> void:
	ps.index = sections.size()
	sections.append(ps)
	for c in ps.cells():
		occupied[c] = ps.index

## True iff every cell of `rect` is free.
func rect_free(rect: Rect2i) -> bool:
	for x in rect.size.x:
		for y in rect.size.y:
			if occupied.has(rect.position + Vector2i(x, y)):
				return false
	return true

## Sections that expose ≥1 entry anchor — the BFS seeds + FR-11-4's alternate-entry rule.
func entry_indices() -> Array:
	var out: Array = []
	for ep in entry_points:
		var s: int = ep.get("section", -1)
		if s >= 0 and s not in out:
			out.append(s)
	return out

func section_def(i: int) -> SectionDef:
	return sections[i].def if i >= 0 and i < sections.size() else null

# --- Deterministic fingerprint (drives test_seed_reproducible) -------------
func to_dict() -> Dictionary:
	var secs: Array = []
	for ps in sections:
		secs.append({"id": String(ps.def.id), "x": ps.origin.x, "y": ps.origin.y})
	return {
		"archetype_id": String(archetype_id),
		"mission_seed": mission_seed,
		"tier": tier,
		"difficulty": difficulty,
		"objective_id": String(objective_id),
		"objective_kind": objective_kind,
		"modifier_ids": _sn_list(modifier_ids),
		"sections": secs,
		"edges": edges.duplicate(true),
		"gates": _gates_digest(),
		"loot": _digest(loot, ["loot_id", "section", "is_mark"]),
		"actors": _digest(actors, ["enemy_id", "section", "carried_item"]),
		"civilians": _digest(civilians, ["section", "carried_item"]),
		"consumables": _digest(consumables, ["gear_id", "section", "count"]),
		"keys": _digest(keys, ["item_id", "section"]),
		"clues": _digest(clues, ["clue_id", "section"]),
		"hazards": _digest(hazards, ["obstacle_id", "section"]),
		"drop_points": _digest(drop_points, ["section"]),
		"reinforce_points": _digest(reinforce_points, ["section"]),
		"entry_points": _digest(entry_points, ["section"]),
		"entry_index": entry_index,
		"objective_index": objective_index,
		"escape_index": escape_index,
		"objective_data": objective_data.duplicate(true),
	}

func _gates_digest() -> Array:
	var out: Array = []
	for g in gates:
		out.append({
			"obstacle_id": String(g.get("obstacle_id", &"")),
			"edge": g.get("edge", -1),
			"effective_difficulty": g.get("effective_difficulty", 1),
			"required_item": String(g.get("required_item", &"")),
		})
	return out

func _digest(rows: Array, keys_wanted: Array) -> Array:
	var out: Array = []
	for r in rows:
		var d: Dictionary = {}
		for k in keys_wanted:
			var v = r.get(k)
			d[k] = String(v) if v is StringName else v
		out.append(d)
	return out

func _sn_list(ids: Array) -> Array:
	var out: Array = []
	for i in ids:
		out.append(String(i))
	return out
