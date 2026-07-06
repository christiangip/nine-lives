extends RefCounted
class_name SaveReconcile
## Read-only forward-compat report for the expansion framework (task 19, FR-19-6). Policy is
## **preserve-but-dormant**: when a pack is disabled/removed, the content ids it contributed stay in the
## permanent account + the Streak verbatim (from_dict restores them; consumers null-tolerate), so
## re-enabling the pack revives every unlock/perk/station with no data loss — the right fit for the
## permanent-Legacy meta + strict-saves pillar. This helper only *reports* which restored ids currently
## resolve to no registered def (per category), for the demo sandbox's forward-compat readout and
## test_pack_toggle. It NEVER mutates state — nothing is ever stripped. See docs/CONTENT_PACKS.md and
## docs/tasks/16_save_system.md. TODO[19].

## { category (StringName) -> Array[StringName] of restored ids absent from that registry }. Empty when
## every referenced id resolves. Only id-based references are reported — Stash special_hook ids and Intel
## reveal keys aren't registry ids and are intentionally omitted.
static func unknown_ids() -> Dictionary:
	var out: Dictionary = {}
	var c := Services.content()
	if c == null:
		return out
	var pm := Services.progression()
	if pm != null:
		_collect(out, &"gear", pm.unlocked_gear, c.gear)
		_collect(out, &"gear", pm.research_done, c.gear)
		_collect(out, &"perks", pm.meta_perks, c.perks)
		_collect(out, &"stations", pm.stations_unlocked, c.stations)
		_collect(out, &"attributes", pm.attributes.keys(), c.attributes)
	var rm := Services.run()
	if rm != null:
		_collect(out, &"edges", rm.edges, c.edges)
	return out

## Total dormant-id count across categories (sandbox convenience).
static func unknown_count() -> int:
	var n := 0
	var d := unknown_ids()
	for cat in d:
		n += (d[cat] as Array).size()
	return n

static func _collect(out: Dictionary, category: StringName, ids, reg) -> void:
	if reg == null or ids == null:
		return
	for raw in ids:
		var id := StringName(raw)
		if String(id).is_empty():
			continue
		if not reg.has(id):
			if not out.has(category):
				out[category] = []
			if id not in out[category]:
				out[category].append(id)
