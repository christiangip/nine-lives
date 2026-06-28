extends Resource
class_name EdgeDef
## Temporary per-Streak perk (drawn 3-at-a-time on Streak level-up).
## Instances in game/resources/edges/. See docs/tasks/12_progression_streak_legacy.md.

@export var id: StringName
@export var display_name: String
@export var description: String
@export var rarity: int = 0                ## 0 common .. 3 legendary
@export var tags: Array[StringName] = []   ## build identity: "ghost","mule","tech"
@export var modifiers: Dictionary = {}     ## stat deltas applied while held
