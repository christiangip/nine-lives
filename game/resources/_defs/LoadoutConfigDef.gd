extends Resource
class_name LoadoutConfigDef
## System-wide loadout tunables — per-slot capacity limits (Armory enforces these, FR-09-1) plus a
## few global weapon/armor knobs the Weapon/Armor models read so there are no magic numbers in logic.
## A single instance indexed by id in Content.loadout (looked up as &"default"), mirroring how the
## other config defs work (DetectionConfigDef / AIConfigDef / MinigameConfigDef).
## See docs/tasks/09_loadout_gear_gadgets.md and GDD §11.

@export var id: StringName = &"default"

## Per-slot capacity (units). Keyed by GearDef.Slot enum int → max total slot_cost equippable.
## A GearDef.Slot value that isn't listed falls back to `default_capacity`.
@export var slot_capacity: Dictionary = {
	GearDef.Slot.TOOL: 3,
	GearDef.Slot.BREACH: 1,
	GearDef.Slot.GADGET: 3,
	GearDef.Slot.WEAPON: 2,
	GearDef.Slot.UTILITY: 2,
	GearDef.Slot.APPAREL: 2,
}
@export var default_capacity: int = 1

# --- Weapon globals (Weapon.gd reads these; per-weapon specifics live in GearDef.params) -----
@export var suppressor_noise_factor: float = 0.25   ## suppressed shot noise = base × this (FR-09-4, feeds 04)
@export var spread_per_recoil: float = 1.0          ## how much accumulated recoil widens spread (deg)
@export var marksmanship_spread_reduction: float = 0.5  ## fraction of spread removed at full Marksmanship effect

# --- Armor globals (Armor.gd reads these) ----------------------------------
@export var armor_regen_delay: float = 4.0          ## seconds after a hit before a broken plate regenerates
@export var armor_regen_per_sec: float = 20.0       ## armor HP restored per second while regenerating
@export var armor_speed_penalty_per_kg: float = 0.01  ## agility tradeoff: move-speed mult loss per kg of armor

## Capacity for a slot (falls back to default_capacity). Pure.
func capacity_for(slot: int) -> int:
	return int(slot_capacity.get(slot, default_capacity))
