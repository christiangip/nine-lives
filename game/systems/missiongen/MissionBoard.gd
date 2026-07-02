extends RefCounted
class_name MissionBoard
## The Job Map board generator (task 11, FR-11-10 / GDD §7.1). Produces 3–5 Contracts whose difficulty
## floor escalates with Streak length (the passed difficulty_floor) and Heat, and rises across the board
## slots so later pins read tougher. Each Contract carries its own reproducible seed (FR-11-8). Pure/
## static + deterministic given the seeded rng. See docs/tasks/11_mission_generation.md.

static func build_board(difficulty_floor: int, heat: float, count: int, rng: RandomNumberGenerator) -> Array:
	var archetypes := generatable_archetypes()
	var board: Array = []
	if archetypes.is_empty():
		return board
	var n := clampi(count, 3, 5)
	for i in n:
		var arch: ArchetypeDef = archetypes[rng.randi_range(0, archetypes.size() - 1)]
		var c := Contract.new()
		c.archetype_id = arch.id
		c.mission_seed = rng.randi()
		c.difficulty = contract_difficulty(difficulty_floor, heat, i)
		c.tier = tier_for_difficulty(c.difficulty)
		c.objective_id = _pick_objective(arch, rng)
		c.bonus_objective_id = _pick_bonus(rng)
		c.modifier_ids = _pick_modifiers(arch, c.tier, heat, rng)
		board.append(c)
	return board

# --- Pure escalation seams (unit-tested) -----------------------------------
## Difficulty score for board slot `index`: floor (Streak length) + slot ramp + Heat bump.
static func contract_difficulty(difficulty_floor: int, heat: float, index: int) -> int:
	return maxi(1, difficulty_floor + index + int(round(clampf(heat, 0.0, 1.0) * 4.0)))

## Difficulty Tier (1..5) from a difficulty score — every 2 points of difficulty adds a tier.
static func tier_for_difficulty(difficulty: int) -> int:
	@warning_ignore("integer_division")
	var t := 1 + (maxi(1, difficulty) - 1) / 2
	return clampi(t, 1, 5)

## The board's difficulty floor — its minimum contract difficulty (drives test_board_escalation).
static func board_difficulty_floor(board: Array) -> int:
	if board.is_empty():
		return 0
	var lo := 1 << 30
	for c in board:
		lo = mini(lo, c.difficulty)
	return lo

# --- Content selection -----------------------------------------------------
static func generatable_archetypes() -> Array:
	var out: Array = []
	if Content == null or Content.archetypes == null:
		return out
	for a in Content.archetypes.all():
		if is_generatable(a):
			out.append(a)
	return out

## An archetype can generate iff it resolves an ENTRY, an ESCAPE, ≥1 INTERIOR, an OBJECTIVE setpiece,
## and declares ≥1 objective. (Malformed/JSON-only archetypes are safely skipped.)
static func is_generatable(arch: ArchetypeDef) -> bool:
	if arch == null or arch.objective_ids.is_empty():
		return false
	if Content == null or Content.sections == null:
		return false
	var has_entry := false
	var has_escape := false
	var has_interior := false
	for sid in arch.section_ids:
		var d := Content.sections.get_def(sid) as SectionDef
		if d == null:
			continue
		match d.kind:
			SectionDef.Kind.ENTRY: has_entry = true
			SectionDef.Kind.ESCAPE: has_escape = true
			SectionDef.Kind.INTERIOR: has_interior = true
	var has_obj := false
	for sid in arch.setpiece_ids:
		if Content.sections.has(sid):
			has_obj = true
	return has_entry and has_escape and has_interior and has_obj

static func _pick_objective(arch: ArchetypeDef, rng: RandomNumberGenerator) -> StringName:
	if arch.objective_ids.is_empty():
		return &""
	return arch.objective_ids[rng.randi_range(0, arch.objective_ids.size() - 1)]

static func _pick_bonus(rng: RandomNumberGenerator) -> StringName:
	if Content == null or Content.objectives == null:
		return &""
	var bonuses: Array = []
	for o in Content.objectives.all():
		if o.is_bonus:
			bonuses.append(o.id)
	if bonuses.is_empty() or rng.randf() < 0.4:
		return &""   # not every contract carries a bonus
	return bonuses[rng.randi_range(0, bonuses.size() - 1)]

static func _pick_modifiers(arch: ArchetypeDef, tier: int, heat: float, rng: RandomNumberGenerator) -> Array[StringName]:
	var out: Array[StringName] = []
	if arch.modifier_pool.is_empty():
		return out
	var want := 0
	if tier >= 2:
		want += 1
	if heat > 0.5 or tier >= 4:
		want += 1
	want = mini(want, arch.modifier_pool.size())
	var pool := arch.modifier_pool.duplicate()
	for _i in want:
		var idx := rng.randi_range(0, pool.size() - 1)
		out.append(pool[idx])
		pool.remove_at(idx)
	return out
