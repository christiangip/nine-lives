extends RefCounted
class_name PlacedSection
## One SectionDef placed on the assembler's integer grid (task 11). Pure data — grid origin + the
## resolved SectionDef + socket bookkeeping; world transforms are derived at realize time (build()).
## Grid cells are square (MissionLayout.CELL_SIZE meters); anchor.pos is in cell units.
## See docs/tasks/11_mission_generation.md.

var index: int = -1
var def: SectionDef
var origin: Vector2i = Vector2i.ZERO   ## min-corner cell
var sockets_used: int = 0

func size() -> Vector2i:
	return def.footprint if def != null else Vector2i.ONE

func rect() -> Rect2i:
	return Rect2i(origin, size())

## Every grid cell this section occupies (for overlap testing).
func cells() -> Array:
	var out: Array = []
	var s := size()
	for x in s.x:
		for y in s.y:
			out.append(origin + Vector2i(x, y))
	return out

## Section-local anchor (cell units) → world position (meters), given the cell size.
func anchor_world(local: Vector3, cell_size: float) -> Vector3:
	return (Vector3(origin.x, 0.0, origin.y) + local) * cell_size

## Section centre in world space (meters).
func center_world(cell_size: float) -> Vector3:
	var s := size()
	return (Vector3(origin.x + s.x * 0.5, 0.0, origin.y + s.y * 0.5)) * cell_size
