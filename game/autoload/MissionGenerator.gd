extends Node
## MissionGenerator — seeded, hybrid-procedural level assembly + population (autoload, task 11).
## Two stages so the hard logic stays headless-testable:
##   1. generate_layout(contract) → a pure MissionLayout (assemble → populate), validated by
##      MissionValidator (the CI-gating solvability proof).
##   2. build(contract) → realizes that layout into a MissionController Node3D tree GameManager swaps in.
## refresh_board() produces the Job Map's 3–5 escalating Contracts. All randomness flows through the one
## seeded _rng, so a seed fully determines a layout + board (FR-11-8). See docs/tasks/11_mission_generation.md
## and GDD §7.5.

var _rng := RandomNumberGenerator.new()

## Assemble + populate a pure, seed-reproducible layout (no scene instancing). Empty layout if the
## contract's archetype can't generate (caller checks `sections.is_empty()`).
func generate_layout(contract: Contract) -> MissionLayout:
	var arch := _archetype(contract.archetype_id)
	if arch == null:
		return MissionLayout.new()
	_rng.seed = contract.mission_seed
	var layout := MissionAssembler.new().assemble(arch, contract, _rng)
	if layout.sections.is_empty():
		return layout
	MissionPopulator.new().populate(layout, arch, contract, _rng)
	return layout

## Build a playable mission scene root from a contract. Validates solvability first (an unsolvable
## layout is a generator bug, so we refuse rather than ship it).
func build(contract: Resource) -> Node3D:
	var c := contract as Contract
	if c == null:
		push_error("MissionGenerator.build: expected a Contract, got %s" % contract)
		return null
	var layout := generate_layout(c)
	if layout.sections.is_empty() or not MissionValidator.validate(layout):
		push_error("MissionGenerator.build: no solvable layout for '%s' seed %d" % [c.archetype_id, c.mission_seed])
		return null
	# Geometry-faithfulness (world-gen Phase 2C): every room should be physically reachable. Non-fatal —
	# corridors + aligned doors connect by construction and the safety slab backstops it, so we warn
	# (the hard proof is test_mission_geometry's seed sweep) rather than refuse a playable mission.
	var geo := MissionGeometry.faithful(layout)
	if not geo.get("ok", true):
		push_warning("MissionGenerator.build: geometry not faithful for '%s' seed %d — unreachable=%s clip_cells=%d"
			% [c.archetype_id, c.mission_seed, str(geo.get("unreachable", [])), int(geo.get("clip_cells", 0))])
	var controller := MissionController.new()
	controller.name = "Mission"
	controller.setup(layout, c)
	return controller

## Produce a fresh set of available contracts for the Job Map (FR-11-10). Escalates with the streak's
## difficulty floor + Heat. Seeded deterministically from (floor, heat) so a board is reproducible.
func refresh_board(difficulty_floor: int, heat: float, count: int = 4, unlocked_archetypes: Array = []) -> Array:
	_rng.seed = hash([difficulty_floor, int(round(clampf(heat, 0.0, 1.0) * 1000.0))])
	return MissionBoard.build_board(difficulty_floor, heat, count, _rng, unlocked_archetypes)

func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value

## Validation hook used by tests + build(): every generated layout MUST be solvable. Accepts either a
## pure MissionLayout (tests) or a built MissionController root (reads its stored layout).
func validate_layout(target) -> bool:
	if target is MissionLayout:
		return MissionValidator.validate(target)
	if target is Node:
		var lay = target.get("layout")
		if lay is MissionLayout:
			return MissionValidator.validate(lay)
	return false

func _archetype(id: StringName) -> ArchetypeDef:
	if Content != null and Content.archetypes != null:
		return Content.archetypes.get_def(id) as ArchetypeDef
	return null
