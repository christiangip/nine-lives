extends RefCounted
class_name EconomyValidator
## Schema/range checks over every economy cost/value table (task 14, FR-14-4 "loaders + validation").
## The ContentRegistry is the *loader* (it hydrates .tres + data/*.json into Def instances); this is
## the *validation* half — a pure static sweep that range-checks loot values, gear research/restock
## costs, attribute cost curves, perk costs, Intel prices, and the EconomyConfigDef dials, returning a
## list of human-readable violations (empty = all tables sane). test_data_tables_valid asserts empty;
## the balancing harness + a designer can call it after editing data/economy.json.
## Pure static, headless-safe (reads Content via the Services locator). See docs/tasks/14_economy_balancing.md.

## All violations across every cost/value table + economy.json. Empty Array means everything passes.
static func validate() -> Array:
	var errors: Array = []
	var c := Services.content()
	if c == null:
		errors.append("Content autoload unavailable — cannot validate economy tables")
		return errors
	_check_loot(c, errors)
	_check_gear(c, errors)
	_check_attributes(c, errors)
	_check_perks(c, errors)
	_check_intel(c, errors)
	_check_economy(c, errors)
	return errors

# --- Per-table checks ------------------------------------------------------
static func _check_loot(c, errors: Array) -> void:
	if c.loot == null:
		return
	for res in c.loot.all():
		var def := res as LootDef
		if def == null:
			continue
		if def.value < 0:
			errors.append("loot '%s': value %d < 0" % [def.id, def.value])

static func _check_gear(c, errors: Array) -> void:
	if c.gear == null:
		return
	for res in c.gear.all():
		var def := res as GearDef
		if def == null:
			continue
		if def.research_cost < 0:
			errors.append("gear '%s': research_cost %d < 0" % [def.id, def.research_cost])
		if def.restock_cost < 0:
			errors.append("gear '%s': restock_cost %d < 0" % [def.id, def.restock_cost])
		# A consumable must have a real stack cap so restock can't overflow. restock_cost 0 is valid —
		# it means "not Fence-restockable" (research/found-only, e.g. Get-Out-of-Jail); the Fence UI
		# already hides those (it lists only restock_cost > 0).
		if def.consumable and def.max_count <= 0:
			errors.append("gear '%s': consumable with max_count %d ≤ 0" % [def.id, def.max_count])

static func _check_attributes(c, errors: Array) -> void:
	if c.attributes == null:
		return
	for res in c.attributes.all():
		var def := res as AttributeDef
		if def == null:
			continue
		if def.effect_per_level < 0.0:
			errors.append("attribute '%s': effect_per_level %f < 0" % [def.id, def.effect_per_level])
		if def.cost_curve.is_empty():
			errors.append("attribute '%s': empty cost_curve" % def.id)
			continue
		if def.cost_curve.size() != def.max_level:
			errors.append("attribute '%s': cost_curve length %d != max_level %d"
				% [def.id, def.cost_curve.size(), def.max_level])
		var prev := 0
		for i in def.cost_curve.size():
			var cost: int = def.cost_curve[i]
			if cost <= 0:
				errors.append("attribute '%s': cost_curve[%d] %d ≤ 0" % [def.id, i, cost])
			if cost < prev:
				errors.append("attribute '%s': cost_curve not monotonic at [%d] (%d < %d)"
					% [def.id, i, cost, prev])
			prev = cost

static func _check_perks(c, errors: Array) -> void:
	if c.perks == null:
		return
	for res in c.perks.all():
		var def := res as PerkDef
		if def == null:
			continue
		if def.legacy_cost < 0:
			errors.append("perk '%s': legacy_cost %d < 0" % [def.id, def.legacy_cost])
		for pre in def.prerequisites:
			if not c.perks.has(pre):
				errors.append("perk '%s': prerequisite '%s' is not a known perk" % [def.id, pre])

static func _check_intel(c, errors: Array) -> void:
	if c.intel == null:
		return
	for res in c.intel.all():
		var def := res as IntelDef
		if def == null:
			continue
		if def.take_cost < 0:
			errors.append("intel '%s': take_cost %d < 0" % [def.id, def.take_cost])
		if def.legacy_cost < 0:
			errors.append("intel '%s': legacy_cost %d < 0" % [def.id, def.legacy_cost])
		if def.take_cost + def.legacy_cost <= 0:
			errors.append("intel '%s': free (take_cost + legacy_cost ≤ 0)" % def.id)
		if def.reveals.is_empty():
			errors.append("intel '%s': reveals nothing" % def.id)

static func _check_economy(c, errors: Array) -> void:
	var econ := EconomyConfigDef.resolve()
	_in_unit_range(errors, "take_fraction", econ.take_fraction)
	_in_unit_range(errors, "fence_fraction", econ.fence_fraction)
	_in_unit_range(errors, "base_catch_chance", econ.base_catch_chance)
	_non_negative(errors, "objective_notoriety", econ.objective_notoriety)
	_non_negative(errors, "heat_multiplier_base", econ.heat_multiplier_base)
	_non_negative(errors, "heat_multiplier_slope", econ.heat_multiplier_slope)
	_non_negative(errors, "legacy_floor", econ.legacy_floor)
	_non_negative(errors, "catch_per_tier", econ.catch_per_tier)
	_non_negative(errors, "catch_per_heat", econ.catch_per_heat)
	if econ.max_contracts_per_streak <= 0:
		errors.append("economy: max_contracts_per_streak %d ≤ 0" % econ.max_contracts_per_streak)
	if econ.target_streak_len_min > econ.target_streak_len_max:
		errors.append("economy: target_streak_len_min %.1f > max %.1f"
			% [econ.target_streak_len_min, econ.target_streak_len_max])
	# Anti-frustration: every Catch must afford the cheapest first Legacy buy (FR-14-5). Cross-check the
	# floor against the real cheapest attribute first-level cost, not just the config's mirror value.
	var cheapest := _cheapest_first_buy(c)
	if cheapest >= 0 and econ.legacy_floor < cheapest:
		errors.append("economy: legacy_floor %d < cheapest first Training buy %d (a Catch can't afford anything)"
			% [econ.legacy_floor, cheapest])
	if econ.legacy_floor < econ.min_first_buy_legacy:
		errors.append("economy: legacy_floor %d < min_first_buy_legacy %d"
			% [econ.legacy_floor, econ.min_first_buy_legacy])

# --- Helpers ---------------------------------------------------------------
## The cheapest first-level attribute cost across the Training catalogue, or -1 if none authored.
static func _cheapest_first_buy(c) -> int:
	if c.attributes == null:
		return -1
	var cheapest := -1
	for res in c.attributes.all():
		var def := res as AttributeDef
		if def != null and not def.cost_curve.is_empty():
			var first: int = def.cost_curve[0]
			if cheapest < 0 or first < cheapest:
				cheapest = first
	return cheapest

static func _in_unit_range(errors: Array, name: String, v: float) -> void:
	if v < 0.0 or v > 1.0:
		errors.append("economy: %s %.3f outside [0,1]" % [name, v])

static func _non_negative(errors: Array, name: String, v: float) -> void:
	if v < 0.0:
		errors.append("economy: %s %.3f < 0" % [name, v])
