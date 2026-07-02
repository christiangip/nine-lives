extends RefCounted
class_name MissionPopulator
## Seeded population pass (task 11, FR-11-4/5/6/9). Scatters loot, patrols, camera/lock hazards,
## objective items, found keys/clues, consumables (FR-09-6), and a pickpockable keycard civilian
## (closes the ↩ From 07/09 hooks) across a MissionLayout's anchors under designer rules — the Mark
## lands in a high-security wing, ≥1 alternate entry exists, and the vault key is placed in a section
## reachable BEFORE its door so MissionValidator passes by construction. Difficulty Tier + Heat +
## ModifierDef effects parameterize guard count/skill and camera/lock density (FR-11-9). Deterministic
## given the seeded rng. See docs/tasks/11_mission_generation.md.

var _layout: MissionLayout
var _archetype: ArchetypeDef
var _contract: Contract
var _rng: RandomNumberGenerator
var _effects: Dictionary = {}
var _flavor: Dictionary = {}
var _guard_skill_mult := 1.0
var _patrol_mult := 1.0
var _camera_density := 0.0
var _lock_difficulty := 0.3
var _lock_diff_add := 0
var _base_enemy: StringName = &"guard"

func populate(layout: MissionLayout, archetype: ArchetypeDef, contract: Contract, rng: RandomNumberGenerator) -> void:
	_layout = layout
	_archetype = archetype
	_contract = contract
	_rng = rng
	_flavor = archetype.security_flavor
	_effects = _merged_effects(contract.modifier_ids)
	var tier_mult := 1.0 + float(maxi(0, contract.tier - 1)) * 0.15 + _layout_heat() * 0.25
	_guard_skill_mult = tier_mult * float(_effects.get("guard_skill_mult", 1.0))
	_patrol_mult = float(_effects.get("patrol_count_mult", 1.0))
	_camera_density = float(_flavor.get("camera_density", 0.0)) + float(_effects.get("camera_density_add", 0.0))
	_lock_difficulty = float(_flavor.get("lock_difficulty", 0.3))
	_lock_diff_add = int(_effects.get("lock_difficulty_add", 0)) + int(round(_layout_heat() * 2.0))
	_base_enemy = _first_roster_of_kind(EnemyDef.Kind.GUARD)

	_collect_anchor_points(&"entry", _layout.entry_points)
	_collect_anchor_points(&"drop", _layout.drop_points)
	_collect_anchor_points(&"reinforce", _layout.reinforce_points)
	_place_patrols()
	_place_loot()
	_place_hazards()
	_place_gates()
	_place_objective()
	_place_keys_and_clues()
	_place_consumables()
	_place_civilian()

# --- Anchors → point lists -------------------------------------------------
func _collect_anchor_points(type: StringName, into: Array) -> void:
	for i in _layout.sections.size():
		var def := _layout.sections[i].def
		for a in def.anchors_of(type):
			into.append({"section": i, "pos": _world(i, a.get("pos", Vector3.ZERO))})

# --- Patrols (FR-11-9: count × Tier/Heat/modifier, skill scaled) -----------
func _place_patrols() -> void:
	for i in _layout.sections.size():
		var def := _layout.sections[i].def
		for a in def.anchors_of(&"patrol"):
			_add_guard(i, a.get("pos", Vector3.ZERO), _pick_patrol_enemy(def.security_tier))
			# Extra patrols from Tier/modifier density.
			if _rng.randf() < (_patrol_mult - 1.0) + 0.1 * float(maxi(0, _contract.tier - 1)):
				_add_guard(i, a.get("pos", Vector3.ZERO) + Vector3(0.4, 0, 0.4), _base_enemy)

func _add_guard(section: int, local: Vector3, enemy_id: StringName) -> void:
	_layout.actors.append({
		"enemy_id": enemy_id,
		"section": section,
		"pos": _world(section, local),
		"carried_item": &"",
		"skill_mult": _guard_skill_mult,
	})

## Tougher roster members appear in higher-security wings / higher tiers.
func _pick_patrol_enemy(security_tier: int) -> StringName:
	var tough := _first_roster_tougher()
	if tough != &"" and (security_tier >= 3 or _contract.tier >= 3) and _rng.randf() < 0.5:
		return tough
	return _base_enemy

# --- Loot (archetype table; higher value in higher-security wings) ---------
func _place_loot() -> void:
	var ids := _archetype.loot_ids
	if ids.is_empty():
		return
	for i in _layout.sections.size():
		var def := _layout.sections[i].def
		for a in def.anchors_of(&"loot"):
			var lid := _pick_loot(def.security_tier)
			_layout.loot.append({
				"loot_id": lid,
				"section": i,
				"pos": _world(i, a.get("pos", Vector3.ZERO)),
				"is_mark": false,
				"value": _loot_value(lid),
			})

func _pick_loot(security_tier: int) -> StringName:
	var ids := _archetype.loot_ids
	# In high-security wings, bias toward the most valuable item in the table.
	if security_tier >= 2 and _rng.randf() < 0.6:
		return _highest_value_loot()
	return ids[_rng.randi_range(0, ids.size() - 1)]

# --- Hazards (in-room cameras/lasers; not traversal gates) ------------------
func _place_hazards() -> void:
	for i in _layout.sections.size():
		var def := _layout.sections[i].def
		if def.security_tier < 2:
			continue
		for a in def.anchors_of(&"cover"):
			if _rng.randf() < _camera_density:
				_add_hazard(&"camera_ptz", i, a.get("pos", Vector3.ZERO))
			elif _rng.randf() < float(_flavor.get("laser_density", 0.0)):
				_add_hazard(&"laser_grid", i, a.get("pos", Vector3.ZERO))

func _add_hazard(obstacle_id: StringName, section: int, local: Vector3) -> void:
	_layout.hazards.append({"obstacle_id": obstacle_id, "section": section, "pos": _world(section, local)})

# --- Gates (the vault door + flavor locks on interior edges) ---------------
func _place_gates() -> void:
	var vault_edge := _edge_of(_layout.objective_index)
	if vault_edge >= 0:
		_make_gate(_vault_gate_obstacle(), vault_edge)
	# Flavor locks on a fraction of the remaining open interior edges (universal-solvable, so safe).
	for ei in _layout.edges.size():
		var e := _layout.edges[ei]
		if int(e.get("gate", -1)) >= 0:
			continue
		if ei == vault_edge:
			continue
		if _touches(e, _layout.entry_index):
			continue   # keep at least the first step ungated
		if _rng.randf() < _lock_difficulty:
			_make_gate(_flavor_lock_obstacle(), ei)

func _vault_gate_obstacle() -> StringName:
	# Silent-alarm banks gate the vault with a keycard door (key found in the level); otherwise an
	# electronic lock. Both are non-minigame-only and stay solvable.
	if bool(_flavor.get("silent_alarms", false)) or _lock_difficulty >= 0.5:
		return &"keycard_door"
	return &"elock_basic"

func _flavor_lock_obstacle() -> StringName:
	return &"elock_basic" if _rng.randf() < 0.5 else &"lock_basic"

func _make_gate(obstacle_id: StringName, edge_index: int) -> void:
	var d := _obstacle(obstacle_id)
	if d == null:
		return
	var sols: Array[StringName] = []
	for s in d.valid_solutions:
		sols.append(s)
	var gate := {
		"obstacle_id": d.id,
		"category": int(d.category),
		"difficulty": d.difficulty_tier,
		"effective_difficulty": d.difficulty_tier + _lock_diff_add,
		"solutions": sols,
		"required_item": d.required_item,
		"clue_id": d.clue_id,
		"minigame_only": d.is_minigame_only(),
		"edge": edge_index,
	}
	_layout.edges[edge_index]["gate"] = _layout.gates.size()
	_layout.gates.append(gate)

# --- Objective (FR-11-5; the Mark rule, FR-11-4) ---------------------------
func _place_objective() -> void:
	var obj := _objective_def(_contract.objective_id)
	var kind := obj.kind if obj != null else ObjectiveDef.Kind.GRAB
	_layout.objective_kind = int(kind)
	var target := {"kind": int(kind), "section": _layout.objective_index}
	match kind:
		ObjectiveDef.Kind.MARK:
			var msec := _highest_security_section()
			var mloot := _highest_value_loot()
			var lp := _local_objective_anchor(msec)
			_layout.loot.append({
				"loot_id": mloot, "section": msec, "pos": _world(msec, lp),
				"is_mark": true, "value": _loot_value(mloot),
			})
			target["mark_section"] = msec
			target["loot_id"] = String(mloot)
		ObjectiveDef.Kind.CRACK, ObjectiveDef.Kind.PUZZLE_ROOM:
			var lp2 := _local_objective_anchor(_layout.objective_index)
			_add_hazard(&"breach_vault", _layout.objective_index, lp2)
			target["obstacle_id"] = "breach_vault"
		ObjectiveDef.Kind.SABOTAGE:
			target["section"] = _section_with_anchor(&"objective", _layout.objective_index)
		ObjectiveDef.Kind.RETRIEVE_DELIVER:
			target["deliver_section"] = _layout.drop_points[0].get("section", -1) if not _layout.drop_points.is_empty() else -1
		_:
			pass
	_layout.objective_data = target

# --- Keys/clues: guarantee gate items are reachable BEFORE their door ------
func _place_keys_and_clues() -> void:
	for g in _layout.gates:
		var item: StringName = StringName(g.get("required_item", &""))
		if item != &"" and not _has_key(item):
			var sidx := _reachable_carrier_section()
			# Prefer the Inspector (a pickpocket/takedown target) as the carrier when the roster has one.
			if _roster_has(&"inspector"):
				_layout.actors.append({
					"enemy_id": &"inspector", "section": sidx,
					"pos": _section_point(sidx), "carried_item": item, "skill_mult": _guard_skill_mult,
				})
			_layout.keys.append({"item_id": item, "section": sidx})
		var clue: StringName = StringName(g.get("clue_id", &""))
		if clue != &"" and not _has_clue(clue):
			_layout.clues.append({"clue_id": clue, "section": _reachable_carrier_section()})

# --- Consumables found as loot (FR-09-6) -----------------------------------
func _place_consumables() -> void:
	const POOL: Array[StringName] = [&"emp", &"smoke", &"throwing_coins", &"thermite"]
	var drops := 1 + _rng.randi_range(0, 2)
	for _n in drops:
		var sidx := _rng.randi_range(0, _layout.sections.size() - 1)
		var gid := POOL[_rng.randi_range(0, POOL.size() - 1)]
		_layout.consumables.append({
			"gear_id": gid, "section": sidx, "pos": _section_point(sidx),
			"count": 1 + _rng.randi_range(0, 1),
		})

# --- Pickpockable keycard civilian (closes ↩ From 07/09) -------------------
func _place_civilian() -> void:
	var sidx := _reachable_carrier_section()
	_layout.civilians.append({
		"section": sidx, "pos": _section_point(sidx), "carried_item": &"office_keycard",
	})

# --- Modifier effects ------------------------------------------------------
func _merged_effects(modifier_ids: Array) -> Dictionary:
	var out: Dictionary = {}
	if Content == null or Content.modifiers == null:
		return out
	for mid in modifier_ids:
		var m := Content.modifiers.get_def(mid) as ModifierDef
		if m == null:
			continue
		for k in m.effects:
			var v = m.effects[k]
			if v is float or v is int:
				# multipliers multiply; additive "_add"/"_mult" handled by key convention.
				if String(k).ends_with("_mult"):
					out[k] = float(out.get(k, 1.0)) * float(v)
				else:
					out[k] = float(out.get(k, 0.0)) + float(v)
			else:
				out[k] = v
	return out

func _layout_heat() -> float:
	# Board escalation already folds Heat into contract.difficulty; use a gentle normalized proxy.
	return clampf(float(_contract.difficulty - _contract.tier) * 0.1, 0.0, 1.0)

# --- Resolution helpers ----------------------------------------------------
func _obstacle(id: StringName) -> ObstacleDef:
	return Content.obstacles.get_def(id) as ObstacleDef if Content != null and Content.obstacles != null else null

func _objective_def(id: StringName) -> ObjectiveDef:
	return Content.objectives.get_def(id) as ObjectiveDef if Content != null and Content.objectives != null else null

func _loot_value(id: StringName) -> int:
	var d := Content.loot.get_def(id) as LootDef if Content != null and Content.loot != null else null
	return d.value if d != null else 0

func _highest_value_loot() -> StringName:
	var best: StringName = _archetype.loot_ids[0] if not _archetype.loot_ids.is_empty() else &""
	var best_v := -1
	for lid in _archetype.loot_ids:
		var v := _loot_value(lid)
		if v > best_v:
			best_v = v
			best = lid
	return best

func _first_roster_of_kind(kind: int) -> StringName:
	for eid in _archetype.enemy_roster:
		var d := _enemy(eid)
		if d != null and d.kind == kind and d.carried_item == &"":
			return eid
	return &"guard"

func _first_roster_tougher() -> StringName:
	for eid in _archetype.enemy_roster:
		var d := _enemy(eid)
		if d != null and d.tier >= 2 and d.carried_item == &"":
			return eid
	return &""

func _roster_has(id: StringName) -> bool:
	return id in _archetype.enemy_roster

func _enemy(id: StringName) -> EnemyDef:
	return Content.enemies.get_def(id) as EnemyDef if Content != null and Content.enemies != null else null

func _highest_security_section() -> int:
	# Highest security_tier, excluding the vault leaf when a non-vault high-sec wing exists — the Mark
	# should sit in a guarded WING, reachable, not always deepest in the vault.
	var best := _layout.objective_index
	var best_tier := -1
	for i in _layout.sections.size():
		var t := _layout.sections[i].def.security_tier
		if i != _layout.objective_index and t > best_tier:
			best_tier = t
			best = i
	if best_tier >= 2:
		return best
	return _layout.objective_index

func _reachable_carrier_section() -> int:
	# Any section except the vault leaf (all such are reachable before the vault door, since only the
	# vault edge carries a non-universal gate). Deterministic pick.
	var pool: Array = []
	for i in _layout.sections.size():
		if i != _layout.objective_index:
			pool.append(i)
	if pool.is_empty():
		return _layout.entry_index
	return pool[_rng.randi_range(0, pool.size() - 1)]

func _edge_of(section: int) -> int:
	for ei in _layout.edges.size():
		var e := _layout.edges[ei]
		if e.a == section or e.b == section:
			return ei
	return -1

func _touches(edge: Dictionary, section: int) -> bool:
	return edge.a == section or edge.b == section

func _has_key(item: StringName) -> bool:
	for k in _layout.keys:
		if StringName(k.get("item_id", &"")) == item:
			return true
	return false

func _has_clue(clue: StringName) -> bool:
	for c in _layout.clues:
		if StringName(c.get("clue_id", &"")) == clue:
			return true
	return false

func _section_with_anchor(type: StringName, fallback: int) -> int:
	for i in _layout.sections.size():
		if _layout.sections[i].def.has_anchor(type):
			return i
	return fallback

func _local_objective_anchor(section: int) -> Vector3:
	var def := _layout.sections[section].def
	var objs := def.anchors_of(&"objective")
	if not objs.is_empty():
		return objs[0].get("pos", Vector3.ZERO)
	return Vector3(float(def.footprint.x) * 0.5, 0.0, float(def.footprint.y) * 0.5)

func _section_point(section: int) -> Vector3:
	return _layout.sections[section].center_world(MissionLayout.CELL_SIZE)

func _world(section: int, local: Vector3) -> Vector3:
	return _layout.sections[section].anchor_world(local, MissionLayout.CELL_SIZE)
