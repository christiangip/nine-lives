extends Resource
class_name LootDef
## Data definition for a single piece of loot. Instances live as .tres in
## game/resources/loot/. See docs/tasks/08_loot_inventory.md and GDD §10.

enum Tier { SMALL, MEDIUM, BULKY, SPECIAL }

@export var id: StringName
@export var display_name: String
@export var tier: Tier = Tier.SMALL
@export var value: int = 0                 ## cash value (feeds Notoriety + Take)
@export var weight: float = 1.0            ## kg  -> Carry Weight cap
@export var volume: float = 1.0            ## L/slots -> Carry Volume cap
@export var needs_bagging: bool = false    ## loose cash/gold must be bagged first
@export var hand_slots: int = 0            ## >0 = two-handed; movement penalty
@export var special_hook: StringName = &"" ## unlock/stash-trophy id for SPECIAL tier
@export var params: Dictionary = {}        ## extra data (e.g. {"set_bonus": {"carry_weight_mult": 0.05}}) — Stash set bonuses (task 13)
@export var mesh: PackedScene
