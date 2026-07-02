extends Node3D
## Dev-only greybox driver for the task-11 manual playtest (F6). Not wired into GameManager — this
## just builds ONE generated mission from a fixed seed and drops it in so you can walk it: two entries,
## patrols with cones, a lock/keycard gate into the vault, loot → a Drop Point, and the Escape (which
## ends the mission → results via MissionController). Change `mission_seed` to reroll the layout;
## everything is data-driven + reproducible. See docs/tasks/11_mission_generation.md.

@export var mission_seed: int = 20250702
@export var archetype: StringName = &"bank"
@export var tier: int = 2

func _ready() -> void:
	var c := Contract.new()
	c.archetype_id = archetype
	c.mission_seed = mission_seed
	c.tier = tier
	c.difficulty = tier
	var arch := Content.archetypes.get_def(archetype) as ArchetypeDef
	if arch != null and not arch.objective_ids.is_empty():
		c.objective_id = arch.objective_ids[0]
	var root := MissionGenerator.build(c)
	if root != null:
		add_child(root)
		print("[MissionGreybox] built '%s' seed %d — %d sections, %d actors, %d gates" % [
			archetype, mission_seed, root.layout.sections.size(), root.layout.actors.size(), root.layout.gates.size()])
	else:
		push_error("[MissionGreybox] build failed for '%s' seed %d" % [archetype, mission_seed])
