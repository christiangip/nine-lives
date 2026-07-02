extends Resource
class_name SectionDef
## Hand-authored modular section metadata — the "prefab contract" (FR-11-1). The assembler reads this
## PURE DATA (footprint, socket count, anchors) WITHOUT instancing the scene, so layout assembly and
## solvability validate headlessly; build() only instances `scene` (or placeholder geometry) at realize
## time. A section is a self-contained stealth space: connection sockets to neighbors, guard-patrol
## anchors, loot anchors, cover, and entry/exit tags (via anchors).
## Instances in game/resources/prefabs_meta/. See docs/tasks/11_mission_generation.md and GDD §7.5.

enum Kind { ENTRY, INTERIOR, OBJECTIVE, SETPIECE, ESCAPE }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.INTERIOR
@export var footprint: Vector2i = Vector2i(2, 2)   ## size in grid cells — drives overlap-free placement
@export var socket_count: int = 2                  ## connection points to neighbors (matched-or-capped, FR-11-2)
@export var security_tier: int = 1                 ## 1 = low; higher wings host the Mark + tougher gates (FR-11-4)
## Anchor points the populator scatters content onto (local, meters). Each is a Dictionary
## {type: StringName, pos: Vector3}; type ∈ &"entry" &"loot" &"patrol" &"cover" &"objective"
## &"drop" &"reinforce". Kept as plain Dictionaries so sections author cleanly in a .tres.
@export var anchors: Array[Dictionary] = []
@export var scene: PackedScene                     ## optional greybox/art geometry; placeholder built if null

# --- Pure query helpers (unit-tested) --------------------------------------
## Every anchor of a given type (a copy of each entry). Property-based; never branches on id.
func anchors_of(type: StringName) -> Array:
	var out: Array = []
	for a in anchors:
		if a is Dictionary and StringName(a.get("type", &"")) == type:
			out.append(a)
	return out

func anchor_count(type: StringName) -> int:
	return anchors_of(type).size()

func has_anchor(type: StringName) -> bool:
	return anchor_count(type) > 0
