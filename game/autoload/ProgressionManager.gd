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
var playtime_seconds: float = 0.0       ## lifetime playtime (accumulated by SaveManager, task 16)

# --- Live content (task 20) ------------------------------------------------
var unlocked_archetypes: Array[StringName] = []  ## archetypes revealed by a milestone (gate: ArchetypeDef.unlock_milestone)
var milestones_reached: Array[StringName] = []   ## milestone ids already granted (idempotency + announce-once)
var season_progress: Dictionary = {}             ## season_id -> {"_baseline": {kind:int}, goal_id: {"claimed": bool}}
var titles_earned: Array[StringName] = []        ## dormant cosmetic/title ids awarded by seasonal goals (rendered later)

## Announced when a milestone is newly reached (EventBus stays frozen — this is a local manager signal,
## the established pattern for readability, mirrored on AudioManager.caption_requested / StationPanel.closed).
signal milestone_unlocked(milestone_id: StringName)

## Milestones reached but not yet shown as a Hideout toast (transient; the unlock itself is persisted).
var _pending_milestone_toasts: Array[StringName] = []

func _ready() -> void:
	# Lifetime stat accrual for seasonal-goal tracking (task 20). ProgressionManager subscribes to the
	# frozen EventBus (never a direct ref to RunManager) — the downward dependency rule is respected.
	if not EventBus.mission_completed.is_connected(_on_mission_completed_stat):
		EventBus.mission_completed.connect(_on_mission_completed_stat)
	if not EventBus.loot_secured.is_connected(_on_loot_secured_stat):
		EventBus.loot_secured.connect(_on_loot_secured_stat)

func _on_mission_completed_stat(_summary: Dictionary) -> void:
	stats[&"contracts_completed"] = int(stats.get(&"contracts_completed", 0)) + 1

func _on_loot_secured_stat(_loot_id: String, value: int) -> void:
	stats[&"loot_value_secured"] = int(stats.get(&"loot_value_secured", 0)) + maxi(0, value)

func add_legacy(amount: int) -> void:
	if amount <= 0:
		return
	legacy += amount
	# Autosave isn't triggered here (that would over-save on every Notoriety→Legacy conversion);
	# the strict policy autosaves at the Hideout / after each station spend / post-mission (task 16).

func spend_legacy(amount: int) -> bool:
	if amount < 0 or legacy < amount:
		return false
	legacy -= amount
	return true

func attribute_level(attr_id: StringName) -> int:
	return int(attributes.get(attr_id, 0))

func is_unlocked(gear_id: StringName) -> bool:
	return gear_id in unlocked_gear

# --- Workshop: research gear (FR-13-5) -------------------------------------
## Research a gear/gadget/weapon-mod at the Workshop: spend its Legacy research_cost (and honour an
## optional params["research_prereq"] chain — data, not an id branch) → permanently unlock it, which
## the research gate Loadout.can_equip already enforces. Idempotent; false if unknown/owned/gated.
func research_gear(gear_id: StringName) -> bool:
	var def := _gear_def(gear_id)
	if not can_research(def, unlocked_gear, legacy):
		return false
	spend_legacy(def.research_cost)
	unlocked_gear.append(def.id)
	if def.id not in research_done:
		research_done.append(def.id)
	return true

## Can this gear be researched now? Not already unlocked, prerequisite (if any) owned, affordable.
## Pure — takes the def + the current unlock set + Legacy, so it's headless-testable. (FR-13-5)
static func can_research(def: GearDef, unlocked: Array, available_legacy: int) -> bool:
	if def == null or def.research_cost <= 0 or def.id in unlocked:
		return false
	var prereq := StringName(def.params.get("research_prereq", &""))
	if prereq != &"" and prereq not in unlocked:
		return false
	return available_legacy >= def.research_cost

func _gear_def(gear_id: StringName) -> GearDef:
	if Content != null and Content.gear != null:
		return Content.gear.get_def(gear_id) as GearDef
	return null

# --- Hideout stations: unlock gating (FR-13-1/2) ---------------------------
## Is a station available to enter? Free stations (no cost + no loot gate) are always open; the rest
## open once bought with Legacy or once their named special loot has been delivered to the Stash.
func is_station_unlocked(def: StationDef) -> bool:
	if def == null:
		return false
	if def.unlock_legacy_cost <= 0 and def.unlock_special_loot == &"":
		return true
	if def.id in stations_unlocked:
		return true
	return def.unlock_special_loot != &"" and def.unlock_special_loot in stash

## Try to unlock a locked station: pay its Legacy cost, OR ratify a loot-gated station whose special
## loot is already in the Stash (no Legacy spent). Returns true only when an unlock actually happens
## (already-unlocked or unaffordable → false).
func try_unlock_station(def: StationDef) -> bool:
	if def == null or def.id in stations_unlocked:
		return false
	if not can_unlock_station(def, legacy, stash):
		return false
	# A loot-gated station whose loot is delivered is paid for by the delivery; otherwise spend Legacy.
	var loot_gated := def.unlock_special_loot != &"" and def.unlock_special_loot in stash
	if not loot_gated:
		spend_legacy(def.unlock_legacy_cost)
	stations_unlocked.append(def.id)
	return true

## Can this station be unlocked right now? Either the gate loot sits in the Stash, or there's enough
## Legacy for its cost. Pure — takes the def + Legacy + Stash. (FR-13-2)
static func can_unlock_station(def: StationDef, available_legacy: int, delivered_stash: Array) -> bool:
	if def == null:
		return false
	if def.unlock_special_loot != &"" and def.unlock_special_loot in delivered_stash:
		return true
	return def.unlock_legacy_cost > 0 and available_legacy >= def.unlock_legacy_cost

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
		stats[&"special_delivered"] = int(stats.get(&"special_delivered", 0)) + 1
		# A delivered trophy may satisfy a special-loot milestone; that's evaluated on the next Hideout
		# arrival (check_milestones), not here — keeping mid-mission banking free of grant side-effects.

## Summed set-bonus value of a modifier key across every special loot in the Stash (FR-13-9). Each
## trophy's LootDef may carry params["set_bonus"] = {key: amount}; systems query this the same way
## Edges/Perks are summed (RunManager.edge_modifier_total / perk_modifier_total). Pure over content.
func stash_set_bonus_total(key: String) -> float:
	var total := 0.0
	for hook in stash:
		var def := _loot_by_hook(hook)
		if def != null:
			var bonus = def.params.get("set_bonus", {})
			if bonus is Dictionary and bonus.has(key):
				total += float(bonus[key])
	return total

## Fence a delivered special loot: remove it from the Stash and return the cash value the sale grants
## (the caller — Fence station — banks it into The Take). 0 if the hook isn't in the Stash. (FR-13-10)
func convert_stash_item(hook_id: StringName) -> int:
	var idx := stash.find(hook_id)
	if idx == -1:
		return 0
	stash.remove_at(idx)
	return convert_value(_loot_by_hook(hook_id))

## The Take a fenced special loot is worth. Pure — a LootDef's value (fallback 0 for an unknown hook).
static func convert_value(def: LootDef) -> int:
	return def.value if def != null else 0

## The LootDef whose special_hook matches `hook` (Stash entries are special_hook ids), or null.
func _loot_by_hook(hook) -> LootDef:
	if Content == null or Content.loot == null:
		return null
	var want := StringName(hook)
	for res in Content.loot.all():
		var def := res as LootDef
		if def != null and def.special_hook == want:
			return def
	return null

# --- Milestone unlock arcs (task 20, FR-20-1) ------------------------------
## The milestone ids whose thresholds are met (lifetime Legacy earned AND, if required, the special loot
## delivered) but which haven't been granted yet. Pure — takes the defs + lifetime metric + stash +
## already-reached set, so it's headless-testable and never branches on an id (only its properties).
static func milestones_satisfied(defs: Array, legacy_earned: int, delivered_stash: Array, reached: Array) -> Array:
	var out: Array = []
	for d in defs:
		var m := d as MilestoneDef
		if m == null or m.id in reached:
			continue
		if legacy_earned < m.threshold_legacy:
			continue
		if m.require_special_loot != &"" and m.require_special_loot not in delivered_stash:
			continue
		out.append(m.id)
	return out

## Resolve any newly-satisfied milestones, AUTO-GRANT each one's unlocks for free (stations/gear/
## archetypes + a one-off Legacy bonus), announce them, and return the ids granted this pass. Idempotent
## (milestones_reached guards re-grants). Called on Hideout entry — every mission end (Catch or escape,
## which is when lifetime Legacy grows and trophies are delivered) routes through the hub — and by the
## Live sandbox demo. Kept OUT of end_streak/add_to_stash so those stay side-effect-free (task 20).
func check_milestones() -> Array:
	var newly: Array = []
	if Content == null or Content.milestones == null:
		return newly
	var earned := int(stats.get(&"legacy_earned", 0))
	for mid in milestones_satisfied(Content.milestones.all(), earned, stash, milestones_reached):
		var m := Content.milestones.get_def(mid) as MilestoneDef
		if m == null:
			continue
		_grant_milestone(m)
		milestones_reached.append(m.id)
		_pending_milestone_toasts.append(m.id)
		newly.append(m.id)
		milestone_unlocked.emit(m.id)
	return newly

func _grant_milestone(m: MilestoneDef) -> void:
	for sid in m.grant_stations:
		if sid not in stations_unlocked:
			stations_unlocked.append(sid)
	for gid in m.grant_gear:
		if gid not in unlocked_gear:
			unlocked_gear.append(gid)
	for aid in m.grant_archetypes:
		if aid not in unlocked_archetypes:
			unlocked_archetypes.append(aid)
	if m.reward_legacy > 0:
		add_legacy(m.reward_legacy)   # a bonus, not "earned via play" — intentionally NOT added to legacy_earned (no chain-trigger)

## Is this archetype revealed by a milestone? (MissionBoard consults ProgressionManager.unlocked_archetypes
## to keep a gated map off the board until earned — passed in by RunManager.refresh_board.)
func is_archetype_unlocked(id: StringName) -> bool:
	return id in unlocked_archetypes

## Take (and clear) the milestone ids reached since the last drain — the Hideout shows a toast per id.
func drain_milestone_toasts() -> Array:
	var out := _pending_milestone_toasts.duplicate()
	_pending_milestone_toasts.clear()
	return out

# --- Seasonal goals (task 20, FR-20-4) -------------------------------------
## Snapshot the current lifetime metrics as this season's baseline on first engagement, so goal progress
## is measured from when the player joined the season (not lifetime totals). Idempotent.
func ensure_season(season: Dictionary) -> void:
	var sid := String(season.get("id", ""))
	if sid == "" or season_progress.has(sid):
		return
	var baseline: Dictionary = {}
	for g in season.get("goals", []):
		if g is Dictionary:
			var kind := String(g.get("kind", ""))
			baseline[kind] = _lifetime_stat(kind)
	season_progress[sid] = {"_baseline": baseline}

## Progress toward a season goal: the lifetime metric for its kind minus the season baseline (≥ 0).
func season_goal_progress(season: Dictionary, goal: Dictionary) -> int:
	var sid := String(season.get("id", ""))
	var kind := String(goal.get("kind", ""))
	var base := 0
	if season_progress.has(sid):
		var bl = season_progress[sid].get("_baseline", {})
		if bl is Dictionary:
			base = int(bl.get(kind, 0))
	return maxi(0, _lifetime_stat(kind) - base)

## Pure: is a goal met? (target treated as ≥ 1 so a mis-authored 0 can't auto-complete.)
static func season_goal_complete(target: int, progress: int) -> bool:
	return progress >= maxi(1, target)

func is_season_goal_claimed(season_id: String, goal_id: String) -> bool:
	if not season_progress.has(season_id):
		return false
	var g = season_progress[season_id].get(goal_id, {})
	return g is Dictionary and bool(g.get("claimed", false))

## Claim a completed, unclaimed season goal: grant its Legacy + record its (dormant) title id. Returns
## true only when a claim actually happens.
func claim_season_reward(season: Dictionary, goal: Dictionary) -> bool:
	ensure_season(season)
	var sid := String(season.get("id", ""))
	var gid := String(goal.get("id", ""))
	if sid == "" or gid == "" or is_season_goal_claimed(sid, gid):
		return false
	if not season_goal_complete(int(goal.get("target", 0)), season_goal_progress(season, goal)):
		return false
	var sp: Dictionary = season_progress[sid]
	sp[gid] = {"claimed": true}
	season_progress[sid] = sp
	add_legacy(int(goal.get("reward_legacy", 0)))
	var title := StringName(goal.get("reward_title", &""))
	if title != &"" and title not in titles_earned:
		titles_earned.append(title)
	return true

## Lifetime metric a season-goal kind reads (task 20). Maps a goal `kind` to its `stats` counter.
func _lifetime_stat(kind: String) -> int:
	return int(stats.get(_stat_key(kind), 0))

func _stat_key(kind: String) -> StringName:
	match kind:
		"contracts_completed": return &"contracts_completed"
		"loot_value": return &"loot_value_secured"
		"special_loot": return &"special_delivered"
		"legacy_earned": return &"legacy_earned"
	return &""

# --- Serialization (task 16, FR-16-2) --------------------------------------
## Snapshot the whole permanent account into a JSON-safe Dictionary (StringName → String). The save
## schema's "permanent" block. Restored by from_dict(); round-tripped by test_save_roundtrip.gd.
func to_dict() -> Dictionary:
	return {
		"legacy": legacy,
		"attributes": _sn_dict_to_str(attributes),
		"unlocked_gear": _sn_array_to_str(unlocked_gear),
		"research_done": _sn_array_to_str(research_done),
		"meta_perks": _sn_array_to_str(meta_perks),
		"stations_unlocked": _sn_array_to_str(stations_unlocked),
		"stash": _sn_array_to_str(stash),
		"stats": _sn_dict_to_str(stats),
		"playtime_seconds": playtime_seconds,
		# Live content (task 20). Additive with defaults → backward-compatible, no SCHEMA_VERSION bump
		# (matches task 19's audited "preserve dormant" policy; from_dict defaults every missing key).
		"unlocked_archetypes": _sn_array_to_str(unlocked_archetypes),
		"milestones_reached": _sn_array_to_str(milestones_reached),
		"season_progress": season_progress.duplicate(true),
		"titles_earned": _sn_array_to_str(titles_earned),
	}

## Rehydrate the permanent account from a to_dict() snapshot (missing keys keep defaults).
func from_dict(d: Dictionary) -> void:
	legacy = int(d.get("legacy", 0))
	attributes = _str_dict_to_sn(d.get("attributes", {}))
	unlocked_gear = _str_array_to_sn(d.get("unlocked_gear", []))
	research_done = _str_array_to_sn(d.get("research_done", []))
	meta_perks = _str_array_to_sn(d.get("meta_perks", []))
	stations_unlocked = _str_array_to_sn(d.get("stations_unlocked", []))
	stash = _str_array_to_sn(d.get("stash", []))
	stats = _str_dict_to_sn(d.get("stats", {}))
	playtime_seconds = float(d.get("playtime_seconds", 0.0))
	# Live content (task 20) — additive; a pre-task-20 save simply keeps the defaults.
	unlocked_archetypes = _str_array_to_sn(d.get("unlocked_archetypes", []))
	milestones_reached = _str_array_to_sn(d.get("milestones_reached", []))
	var sp = d.get("season_progress", {})
	season_progress = (sp as Dictionary).duplicate(true) if sp is Dictionary else {}
	titles_earned = _str_array_to_sn(d.get("titles_earned", []))

# JSON has no StringName type: arrays/dicts of StringName ids serialize as String and rehydrate back.
static func _sn_array_to_str(arr: Array) -> Array:
	var out: Array = []
	for v in arr:
		out.append(String(v))
	return out

static func _str_array_to_sn(arr) -> Array[StringName]:
	var out: Array[StringName] = []
	if arr is Array:
		for v in arr:
			out.append(StringName(v))
	return out

## StringName-keyed dict → String-keyed (values kept as-is: ints for attributes/stats).
static func _sn_dict_to_str(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		out[String(k)] = d[k]
	return out

static func _str_dict_to_sn(d) -> Dictionary:
	var out: Dictionary = {}
	if d is Dictionary:
		for k in d:
			out[StringName(k)] = int(d[k])
	return out
