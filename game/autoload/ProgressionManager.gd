extends Node
## ProgressionManager — permanent (cross-run) account. Survives the Catch.
## Autoload. Legacy currency, attribute levels, unlocks/research, hideout state, and the Legacy
## sinks: Training (attributes, §5.5) and the Legacy Board (permanent Perks). Hideout station UI
## (task 13) drives these methods; the maths lives in pure static seams so they're headless-testable.
## See docs/tasks/12_progression_streak_legacy.md and GDD §5.2 / §5.5.

var legacy: int = 0                     ## permanent meta-currency (was "Soul XP")
var attributes: Dictionary = {}         ## attr_id -> level (see GDD §5.5)
var unlocked_gear: Array[StringName] = []
var research_done: Array[StringName] = []
var meta_perks: Array[StringName] = []  ## always-on permanent passives (Legacy Board)
var stations_unlocked: Array[StringName] = []
var stash: Array[StringName] = []       ## delivered special/unique loot
var stats: Dictionary = {}              ## lifetime statistics

func add_legacy(amount: int) -> void:
	if amount <= 0:
		return
	legacy += amount
	# TODO[16]: trigger autosave

func spend_legacy(amount: int) -> bool:
	if amount < 0 or legacy < amount:
		return false
	legacy -= amount
	return true

func attribute_level(attr_id: StringName) -> int:
	return int(attributes.get(attr_id, 0))

func is_unlocked(gear_id: StringName) -> bool:
	return gear_id in unlocked_gear

# --- Training: attributes (FR-12-6) ----------------------------------------
## Buy one level of an attribute at the Training station. Spends the per-level Legacy cost from the
## AttributeDef.cost_curve and raises the level; the effect feeds the relevant system via
## attribute_effect(). Returns false if the attribute is unknown, maxed, or unaffordable.
func train_attribute(attr_id: StringName) -> bool:
	var def := _attribute_def(attr_id)
	if def == null:
		return false
	var level := attribute_level(attr_id)
	var cost := attribute_cost(def, level)
	if cost < 0:
		return false   # maxed or no authored cost
	if not spend_legacy(cost):
		return false
	attributes[attr_id] = level + 1
	return true

## The trained effect of an attribute: level × effect_per_level (§5.5). 0.0 if untrained/unknown.
func attribute_effect(attr_id: StringName) -> float:
	var def := _attribute_def(attr_id)
	if def == null:
		return 0.0
	return float(attribute_level(attr_id)) * def.effect_per_level

func _attribute_def(attr_id: StringName) -> AttributeDef:
	if Content != null and Content.attributes != null:
		return Content.attributes.get_def(attr_id) as AttributeDef
	return null

## Legacy cost to raise `def` from `current_level` to the next. -1 if maxed or the curve doesn't
## reach that level (so callers treat it as "can't train"). Pure — takes the def, no autoloads.
static func attribute_cost(def: AttributeDef, current_level: int) -> int:
	if def == null or current_level >= def.max_level:
		return -1
	if current_level >= 0 and current_level < def.cost_curve.size():
		return def.cost_curve[current_level]
	return -1

# --- Legacy Board: permanent Perks (FR-12-7) -------------------------------
## Buy a permanent always-on Perk. Requires its prerequisites already owned and enough Legacy;
## idempotent (a re-buy is a no-op). Returns true only when a purchase actually happened.
func buy_perk(perk_id: StringName) -> bool:
	var def := _perk_def(perk_id)
	if not can_buy_perk(def, meta_perks, legacy):
		return false
	spend_legacy(def.legacy_cost)
	meta_perks.append(def.id)
	return true

func has_perk(perk_id: StringName) -> bool:
	return perk_id in meta_perks

## Summed value of a modifier key across all owned Perks (mirrors RunManager.edge_modifier_total),
## so permanent passives are queried the same way temporary Edges are.
func perk_modifier_total(key: String) -> float:
	var total := 0.0
	if Content == null or Content.perks == null:
		return total
	for pid in meta_perks:
		var def := Content.perks.get_def(pid) as PerkDef
		if def != null and def.modifiers.has(key):
			total += float(def.modifiers[key])
	return total

func _perk_def(perk_id: StringName) -> PerkDef:
	if Content != null and Content.perks != null:
		return Content.perks.get_def(perk_id) as PerkDef
	return null

## Can this Perk be bought? Prereqs ⊆ owned, affordable, not already owned. Pure — takes the def.
static func can_buy_perk(def: PerkDef, owned: Array, available_legacy: int) -> bool:
	if def == null or def.id in owned:
		return false
	for pre in def.prerequisites:
		if pre not in owned:
			return false
	return available_legacy >= def.legacy_cost

# --- Stash (FR-08-9) -------------------------------------------------------
## Register a delivered special/unique loot's hook id into the permanent Stash (FR-08-9, GDD
## §10.5). Idempotent. The Stash set-bonus logic is task 13's; this is the append task 08's
## secured-loot banking needs to make "delivering them unlocks Stash trophies" real.
func add_to_stash(hook_id: StringName) -> void:
	if hook_id != &"" and hook_id not in stash:
		stash.append(hook_id)
