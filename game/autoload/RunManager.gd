extends Node
## RunManager — current Streak (per-run) state. Resets on Catch.
## Autoload. Holds Notoriety, Streak Level, Edges, Heat, The Take, Job Map, and owns the
## roguelite engine: Notoriety → Streak Levels (draw-3 Edges), the performance-multiplier
## stack, and the Catch conversion Notoriety × Heat-multiplier → permanent Legacy (task 12).
## See docs/tasks/12_progression_streak_legacy.md and GDD §5.

var notoriety: int = 0
var streak_level: int = 1
var streak_length: int = 0          ## contracts completed this streak
var heat: float = 0.0               ## 0..1; rises on alarms/going loud
var take: int = 0                   ## per-streak cash currency
var edges: Array[StringName] = []   ## chosen temporary perks (Edge ids), applied while held
var job_board: Array = []           ## available contracts (+ seeds)
var committed: bool = false         ## true once an alarm is raised (strict saves)
var _loadout: Loadout               ## the Streak's equipped gear (task 09); lazily created

# Per-mission performance tracking (reset each mission; feeds the multiplier stack, FR-12-1).
var _alarm_this_mission: bool = false
var _spotted_this_mission: bool = false

## Deterministic RNG for the Edge draw. Seeded once; tests can reseed for reproducibility.
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if not EventBus.alarm_tripped.is_connected(_on_alarm_tripped):
		EventBus.alarm_tripped.connect(_on_alarm_tripped)
	if not EventBus.player_spotted.is_connected(_on_player_spotted):
		EventBus.player_spotted.connect(_on_player_spotted)
	if not EventBus.mission_completed.is_connected(_on_mission_completed):
		EventBus.mission_completed.connect(_on_mission_completed)

# --- Config access ---------------------------------------------------------
## The progression tunables (Content.progression &"default"), with a code fallback so headless
## seams never crash. Mirrors PursuitConfigDef's _heat_for_alarm pattern.
func _cfg() -> ProgressionConfigDef:
	var cfg: ProgressionConfigDef = null
	if Content != null and Content.progression != null:
		cfg = Content.progression.get_def(&"default") as ProgressionConfigDef
	if cfg == null:
		cfg = ProgressionConfigDef.new()
	return cfg

# --- Per-mission event tracking --------------------------------------------
## An alarm (silent or loud) commits the Streak — no more mid-mission save-scumming (strict saves) —
## and raises Heat for the remainder of the Streak. Task 10 owns this trigger.
func _on_alarm_tripped(kind: String, _position: Vector3) -> void:
	committed = true
	_alarm_this_mission = true
	raise_heat(_heat_for_alarm(kind))

func _on_player_spotted(_by_actor_id: int) -> void:
	_spotted_this_mission = true

func _heat_for_alarm(kind: String) -> float:
	var cfg: PursuitConfigDef = null
	if Content != null and Content.pursuit != null:
		cfg = Content.pursuit.get_def(&"default") as PursuitConfigDef
	if cfg == null:
		cfg = PursuitConfigDef.new()
	return cfg.heat_per_loud_alarm if kind == "loud" else cfg.heat_per_silent_alarm

## A successfully completed contract (escape). Bump the Streak length, award the objective
## Notoriety × this mission's performance multiplier (FR-12-1), then refresh the board so the
## next contract escalates (FR-11-10). A Catch never reaches here — it calls end_streak() directly.
func _on_mission_completed(summary: Dictionary) -> void:
	streak_length += 1
	var cfg := _cfg()
	var flags := _performance_flags(summary, cfg)
	var perf := stack_multiplier(flags, cfg)
	add_notoriety(int(round(cfg.objective_notoriety * perf)))
	_reset_mission_tracking()
	refresh_board()

## The performance flags this mission earned, from RunManager's own per-mission tracking (alarm/
## spotted) plus the MissionController summary (full_clear / no_kill / elapsed_seconds vs par).
## Used by stack_multiplier (FR-12-1).
func _performance_flags(summary: Dictionary, cfg: ProgressionConfigDef) -> Dictionary:
	var elapsed := float(summary.get("elapsed_seconds", -1.0))
	return {
		"no_alarm": not _alarm_this_mission,
		"stealth": not _spotted_this_mission,
		"no_kill": bool(summary.get("no_kill", true)),
		"speed": elapsed >= 0.0 and elapsed <= cfg.default_par_seconds,
		"full_clear": bool(summary.get("full_clear", false)),
	}

func _reset_mission_tracking() -> void:
	_alarm_this_mission = false
	_spotted_this_mission = false

# --- Loadout ---------------------------------------------------------------
## The per-Streak equipped Loadout (FR-09-8). The Armory (task 13) mutates it between missions and
## the save system (task 16) serializes it; PlayerController reads it for gadget queries. Lazily
## created so a fresh Streak always has a valid (empty) loadout.
func loadout() -> Loadout:
	if _loadout == null:
		_loadout = Loadout.new()
	return _loadout

# --- Streak lifecycle ------------------------------------------------------
func start_new_streak() -> void:
	notoriety = 0; streak_level = 1; streak_length = 0
	heat = 0.0; take = 0; edges.clear(); committed = false
	_reset_mission_tracking()
	refresh_board()

## (Re)fill the Job Map from MissionGenerator, escalating with Streak length + Heat (FR-11-10). Called
## on a fresh Streak and after each completed contract. The difficulty floor rises with streak_length.
func refresh_board() -> void:
	if MissionGenerator != null:
		job_board = MissionGenerator.refresh_board(1 + streak_length, heat)

# --- Notoriety accrual + Streak Levels (FR-12-1, FR-12-2) ------------------
## Bank Notoriety. Held Edges with a "notoriety_mult" modifier scale the gain (e.g. Fence
## Connections +10%). Then check for a Streak level-up, which offers a choice of 3 Edges. The raw
## secured-loot path (task 08) calls this with no Edges held → unchanged ×1.0 accumulation.
func add_notoriety(amount: int, apply_edges: bool = true) -> void:
	if amount <= 0:
		return
	var gained := amount
	if apply_edges:
		gained = int(round(amount * (1.0 + edge_modifier_total("notoriety_mult"))))
	notoriety += gained
	EventBus.notoriety_gained.emit(gained, notoriety)
	_check_level_up()

## Promote the Streak Level for every threshold the new Notoriety total has passed, offering a
## draw of Edges at each level (FR-12-2). Emits streak_level_up(level, edge_choices).
func _check_level_up() -> void:
	var cfg := _cfg()
	var target := level_for_notoriety(notoriety, cfg.streak_level_thresholds)
	while streak_level < target:
		streak_level += 1
		var choices := draw_edges(_edge_pool(), cfg.edge_choices_per_level, cfg.edge_rarity_weights, _rng)
		EventBus.streak_level_up.emit(streak_level, choices)

## The full pool of Edge ids available to draw from (Content.edges). Empty headlessly with no content.
func _edge_pool() -> Array:
	if Content != null and Content.edges != null:
		return Content.edges.all()
	return []

## Accept an offered Edge into the Streak. It applies its modifiers while held and vanishes on Catch
## (start_new_streak clears `edges`). Ignores duplicates.
func choose_edge(edge_id: StringName) -> void:
	if edge_id != &"" and edge_id not in edges:
		edges.append(edge_id)

## Summed value of a modifier key across all currently-held Edges (e.g. "notoriety_mult",
## "carry_weight_mult"). Systems query this to apply Edge effects — the readable, testable seam
## for "modifiers apply while held, vanish on Catch" (FR-12-2).
func edge_modifier_total(key: String) -> float:
	var total := 0.0
	if Content == null or Content.edges == null:
		return total
	for eid in edges:
		var def := Content.edges.get_def(eid) as EdgeDef
		if def != null and def.modifiers.has(key):
			total += float(def.modifiers[key])
	return total

# --- Heat (FR-10-3, FR-12-3) -----------------------------------------------
## Raise Heat toward the 0..1 ceiling and announce it. Going loud / every alarm calls this.
func raise_heat(amount: float) -> void:
	if amount <= 0.0:
		return
	heat = clampf(heat + amount, 0.0, 1.0)
	EventBus.heat_changed.emit(heat)
	# High Heat escalates later contracts' security via refresh_board(streak_len, heat) — task 11.

## The Legacy payout multiplier the current Heat buys (FR-12-3). A hot, loud Streak banks more
## Legacy per Notoriety — but is likelier to end early.
func heat_multiplier() -> float:
	var cfg := _cfg()
	return heat_multiplier_for(heat, cfg.heat_multiplier_base, cfg.heat_multiplier_slope)

# --- The Catch: conversion → Legacy → reset (FR-12-4, FR-12-9) -------------
## The Streak ends (Caught). Convert accrued Notoriety × Heat-multiplier → permanent Legacy (floored
## for anti-frustration), bank it, announce streak_ended, then reset to a fresh low-difficulty
## Streak. Returns the Legacy awarded. Task 10's Catch handoff calls this.
func end_streak(reason: String) -> int:
	var cfg := _cfg()
	var awarded := convert_to_legacy(notoriety, heat_multiplier(), cfg.legacy_floor)
	ProgressionManager.add_legacy(awarded)
	_bump_stat(&"streaks_caught", 1)
	_bump_stat(&"legacy_earned", awarded)
	EventBus.streak_ended.emit(reason, awarded)
	start_new_streak()
	return awarded

## Per-Streak cash from secured loot (task 08). A straight passthrough for now.
func add_take(amount: int) -> void:
	if amount <= 0:
		return
	take += amount
	# TODO[14]: FR-14-2 — Take = a % of secured cash value, not a 1:1 passthrough. This is the
	# real base `take` accrual task 08's banking needs now; 14's "M2 wiring" scales it.

func _bump_stat(stat_id: StringName, amount: int) -> void:
	if ProgressionManager != null:
		ProgressionManager.stats[stat_id] = int(ProgressionManager.stats.get(stat_id, 0)) + amount

# --- Pure static seams (headless-testable, no autoload/tree deps) ----------
## Streak Level for a Notoriety total: 1 + the number of cumulative thresholds passed (FR-12-2).
static func level_for_notoriety(total: int, thresholds: Array) -> int:
	var level := 1
	for t in thresholds:
		if total >= int(t):
			level += 1
		else:
			break
	return level

## Stacked performance multiplier from a flags dict + config (FR-12-1). Base ×1.0, each enabled
## bonus adds its fraction. Edge effects are applied separately (add_notoriety), never here.
static func stack_multiplier(flags: Dictionary, cfg: ProgressionConfigDef) -> float:
	var m := 1.0
	if bool(flags.get("stealth", false)):
		m += cfg.bonus_stealth
	if bool(flags.get("no_alarm", false)):
		m += cfg.bonus_no_alarm
	if bool(flags.get("no_kill", false)):
		m += cfg.bonus_no_kill
	if bool(flags.get("speed", false)):
		m += cfg.bonus_speed
	if bool(flags.get("full_clear", false)):
		m += cfg.bonus_full_clear
	return m

## Draw `count` distinct Edge defs from `pool`, weighted by rarity (rarer = lower weight). Returns
## an Array of Edge ids (StringName). If the pool is smaller than count, returns all of it (FR-12-2/8).
static func draw_edges(pool: Array, count: int, rarity_weights: Array, rng: RandomNumberGenerator) -> Array:
	var remaining: Array = pool.duplicate()
	var out: Array = []
	while out.size() < count and not remaining.is_empty():
		var total_weight := 0.0
		for def in remaining:
			total_weight += _edge_weight(def, rarity_weights)
		var roll := rng.randf() * total_weight if rng != null else 0.0
		var pick_index := 0
		var acc := 0.0
		for i in remaining.size():
			acc += _edge_weight(remaining[i], rarity_weights)
			if roll <= acc:
				pick_index = i
				break
		var chosen = remaining[pick_index]
		remaining.remove_at(pick_index)
		out.append(StringName(chosen.get("id")) if chosen is Resource else StringName(chosen))
	return out

static func _edge_weight(def, rarity_weights: Array) -> float:
	var rarity := 0
	if def is Resource:
		rarity = int(def.get("rarity"))
	if rarity >= 0 and rarity < rarity_weights.size():
		return maxf(0.0001, float(rarity_weights[rarity]))
	return 0.0001

## Payout multiplier for a Heat level (FR-12-3). Heat 0..1 → base .. base+slope.
static func heat_multiplier_for(current_heat: float, base: float, slope: float) -> float:
	return base + clampf(current_heat, 0.0, 1.0) * slope

## Notoriety × Heat-multiplier → Legacy, floored for anti-frustration (FR-12-4/9).
static func convert_to_legacy(total_notoriety: int, heat_mult: float, floor_amount: int) -> int:
	var raw := int(round(float(total_notoriety) * heat_mult))
	return maxi(raw, floor_amount)
