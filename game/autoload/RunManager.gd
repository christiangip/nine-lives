extends Node
## RunManager — current Streak (per-run) state. Resets on Catch.
## Autoload. Holds Notoriety, Streak Level, Edges, Heat, The Take, Job Map, and owns the
## roguelite engine: Notoriety → Streak Levels (draw-3 Edges), the performance-multiplier
## stack, and the Catch conversion Notoriety × Heat-multiplier → permanent Legacy (task 12).
## See docs/tasks/12_progression_streak_legacy.md and GDD §5.

## Mission-scoped alert lifecycle (misc-fixes-3 issue 1). CALM until an alarm trips → PURSUIT while the
## law is actively hunting → ALERTED once the pursuit times out for lack of contact: the level stays
## heightened for the rest of the mission (guards see further/faster) and a fresh alarm re-escalates to
## PURSUIT. PursuitDirector owns the ticking timeline; this is the readable state everyone else queries.
enum AlertState { CALM, PURSUIT, ALERTED }

var notoriety: int = 0
var streak_level: int = 1
var streak_length: int = 0          ## contracts completed this streak
var heat: float = 0.0               ## 0..1; rises on alarms/going loud
var alert_state: int = AlertState.CALM   ## mission-scoped; reset on every mission entry
var take: int = 0                   ## per-streak cash currency
var edges: Array[StringName] = []   ## chosen temporary perks (Edge ids), applied while held
var job_board: Array = []           ## available contracts (+ seeds)
var intel_by_seed: Dictionary = {}  ## mission_seed(int) -> Array[String reveal keys] bought at the Planning Table (task 13)
var committed: bool = false         ## true once an alarm is raised (strict saves)
var last_contract: String = ""      ## display name of the most recent contract entered (save meta, task 16)
var _loadout: Loadout               ## the Streak's equipped gear (task 09); lazily created

# --- Live Challenges (task 20, FR-20-2) — a standalone daily/weekly run, ISOLATED from the Streak ---
var challenge_mode: bool = false            ## true while a Challenge mission is active (transient)
var _streak_snapshot: Dictionary = {}       ## the real Streak, snapshotted on begin_challenge, restored on end
var _challenge_seed: int = 0
var _challenge_kind: String = ""
var _challenge_reward: int = 0
var _challenge_results: Dictionary = {}      ## the results payload GameManager.goto_results consumes

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

## The economy tunables (Content.economy &"default"), with a schema-default fallback so headless seams
## never crash. Task 14 took over the payout dials (Take fraction, Notoriety multipliers, Heat slope,
## Legacy floor) from ProgressionConfigDef via the `↩ From 12` handoff; _cfg() keeps the streak-
## *structure* dials (level thresholds, Edge weights, par time). See EconomyConfigDef.
func _econ() -> EconomyConfigDef:
	return EconomyConfigDef.resolve()

# --- Per-mission event tracking --------------------------------------------
## An alarm (silent or loud) commits the Streak — no more mid-mission save-scumming (strict saves) —
## and raises Heat for the remainder of the Streak. Task 10 owns this trigger.
func _on_alarm_tripped(kind: String, _position: Vector3) -> void:
	committed = true
	_alarm_this_mission = true
	# Any alarm (including one raised while already ALERTED) puts the level back into an active hunt.
	alert_state = AlertState.PURSUIT
	raise_heat(_heat_for_alarm(kind))
	# Strict saves (Q5, FR-16-5): flip the on-disk checkpoint flag the instant we commit, so a
	# hot-quit mid-mission resolves as the Catch on next launch. One-way + un-save-scummable (it can
	# only ever cost the player), so it's the one allowed mid-mission disk touch — no progress saved.
	# NEVER during a standalone Challenge (task 20): a hot-quit mid-Challenge must not Catch the real Streak.
	if SaveManager != null and not challenge_mode:
		SaveManager.mark_committed()

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
	if challenge_mode:
		# A completed Challenge escape: record it + stage results; never touches the endless Streak.
		_record_challenge(summary, true)
		return
	streak_length += 1
	var cfg := _cfg()          # ProgressionConfigDef — par time gates the speed flag
	var econ := _econ()        # EconomyConfigDef — the tunable payout dials (FR-14-3)
	var flags := _performance_flags(summary, cfg)
	var perf := stack_multiplier(flags, econ)
	add_notoriety(int(round(econ.objective_notoriety * perf)))
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

## The pursuit lost contact for pursuit_lost_timeout seconds: the hunt is called off, but the level stays
## on edge for the rest of the mission (DetectionSensor sharpens its senses while ALERTED). PursuitDirector
## calls this immediately before broadcasting pursuit_phase_changed(0).
func enter_alerted() -> void:
	alert_state = AlertState.ALERTED

func _reset_mission_tracking() -> void:
	_alarm_this_mission = false
	_spotted_this_mission = false
	alert_state = AlertState.CALM

## Public seam for GameManager: clear this-mission tracking at the start of every mission entry, so a
## previous mission's exit path that deliberately skips the normal end-of-mission bookkeeping (a clean
## Pause-Menu bug-out, Q5) can never leak a stale spotted/alarm flag forward into the next contract's
## performance bonuses.
func reset_mission_tracking() -> void:
	_reset_mission_tracking()

# --- Loadout ---------------------------------------------------------------
## The per-Streak equipped Loadout (FR-09-8). The Armory (task 13) mutates it between missions and
## the save system (task 16) serializes it; PlayerController reads it for gadget queries. Lazily
## created so a fresh Streak always has a valid (empty) loadout.
func loadout() -> Loadout:
	if _loadout == null:
		_loadout = Loadout.new()
	return _loadout

# --- Serialization (task 16, FR-16-2) --------------------------------------
## Snapshot the current Streak into a JSON-safe Dictionary — the save schema's "streak" block. Folds
## in the equipped Loadout (task 09's to_dict), the Contract job board, and bought Intel. `committed`
## rides along as normal Streak state; the mid-mission hot-quit checkpoint is SaveManager's own
## top-level `active_mission_committed` flag, kept separate so a safe hub save isn't read as a Catch.
func to_dict() -> Dictionary:
	var board: Array = []
	for c in job_board:
		if c is Contract:
			board.append((c as Contract).to_dict())
	var intel: Dictionary = {}
	for seed in intel_by_seed:
		intel[str(seed)] = (intel_by_seed[seed] as Array).duplicate()
	return {
		"notoriety": notoriety,
		"streak_level": streak_level,
		"streak_length": streak_length,
		"heat": heat,
		"take": take,
		"edges": ProgressionManager._sn_array_to_str(edges),
		"committed": committed,
		"last_contract": last_contract,
		"loadout": loadout().to_dict(),
		"job_board": board,
		"intel_by_seed": intel,
	}

## Rehydrate the Streak from a to_dict() snapshot (missing keys keep defaults).
func from_dict(d: Dictionary) -> void:
	notoriety = int(d.get("notoriety", 0))
	streak_level = int(d.get("streak_level", 1))
	streak_length = int(d.get("streak_length", 0))
	heat = float(d.get("heat", 0.0))
	take = int(d.get("take", 0))
	edges = ProgressionManager._str_array_to_sn(d.get("edges", []))
	committed = bool(d.get("committed", false))
	last_contract = String(d.get("last_contract", ""))
	loadout().from_dict(d.get("loadout", {}))
	job_board = []
	for cd in d.get("job_board", []):
		job_board.append(Contract.from_data(cd))
	intel_by_seed = {}
	for seed_key in d.get("intel_by_seed", {}):
		var reveals: Array = []
		for r in d["intel_by_seed"][seed_key]:
			reveals.append(String(r))
		intel_by_seed[int(seed_key)] = reveals
	_reset_mission_tracking()

# --- Streak lifecycle ------------------------------------------------------
func start_new_streak() -> void:
	notoriety = 0; streak_level = 1; streak_length = 0
	heat = 0.0; take = 0; edges.clear(); committed = false
	intel_by_seed.clear()
	_reset_mission_tracking()
	refresh_board()

## (Re)fill the Job Map from MissionGenerator, escalating with Streak length + Heat (FR-11-10). Called
## on a fresh Streak and after each completed contract. The difficulty floor rises with streak_length.
func refresh_board() -> void:
	if MissionGenerator != null:
		var unlocked: Array = ProgressionManager.unlocked_archetypes if ProgressionManager != null else []
		job_board = MissionGenerator.refresh_board(1 + streak_length, heat, 4, unlocked)
		_apply_global_modifiers()

## Rotating global modifiers (task 20, FR-20-3): append the currently-active event modifier(s) to every
## board contract, so a "blackout week" affects the whole board for its period. Flows through the existing
## MissionPopulator._merged_effects with zero populator changes; deduped so a contract's own roll isn't doubled.
func _apply_global_modifiers() -> void:
	var active := LiveOps.active_modifiers(LiveOps.config())
	if active.is_empty():
		return
	for c in job_board:
		if c is Contract:
			for mid in active:
				var m := StringName(mid)
				if m != &"" and m not in c.modifier_ids:
					c.modifier_ids.append(m)

# --- Live Challenges (task 20, FR-20-2): isolated standalone runs ----------
## Enter Challenge mode: snapshot the real Streak, then zero the transient run currencies so the
## Challenge mission starts clean (the equipped Loadout is kept — the player brings their gear).
## Restored verbatim by end_challenge, so a Challenge (even a Catch in it) never touches the Streak.
func begin_challenge(seed: int, kind: String, reward: int) -> void:
	_streak_snapshot = to_dict()
	challenge_mode = true
	_challenge_seed = seed
	_challenge_kind = kind
	_challenge_reward = reward
	_challenge_results = {}
	notoriety = 0; streak_level = 1; heat = 0.0; take = 0
	committed = false; edges.clear()
	_reset_mission_tracking()

## Leave Challenge mode, restoring the snapshotted Streak exactly. GameManager.goto_results calls this
## after a Challenge ends (or enter_challenge calls it on a failed build).
func end_challenge() -> void:
	if not _streak_snapshot.is_empty():
		from_dict(_streak_snapshot)
	challenge_mode = false
	_streak_snapshot = {}
	_challenge_results = {}

## Record a Challenge attempt to the local leaderboard + grant the one-time first-clear Legacy reward,
## and stage the results payload GameManager.goto_results consumes. Does NOT restore/transition.
func _record_challenge(summary: Dictionary, success: bool) -> void:
	var elapsed := float(summary.get("elapsed_seconds", 0.0))
	var secured := int(summary.get("secured_value", 0))
	var already := LiveChallenges.is_completed(_challenge_seed)
	LiveChallenges.record(_challenge_seed, _challenge_kind, elapsed, secured, success)
	var reward := 0
	if success and not already and _challenge_reward > 0:
		reward = _challenge_reward
		if ProgressionManager != null:
			ProgressionManager.add_legacy(reward)
	var best := LiveChallenges.best_for(_challenge_seed)
	_challenge_results = {
		"challenge": true,
		"challenge_kind": _challenge_kind,
		"outcome": "success" if success else "caught",
		"secured_value": secured,
		"elapsed_seconds": elapsed,
		"best_seconds": float(best.get("best_seconds", elapsed if success else 0.0)),
		"reward_legacy": reward,
	}

## GameManager.goto_results pulls the staged Challenge results (a copy; {} if none staged).
func consume_challenge_results() -> Dictionary:
	return _challenge_results.duplicate()

# --- Planning Table: Intel (FR-13-3/8, closes ↩ From 06 reveal half) --------
## Buy an Intel packet for a specific board contract, spending its Take (and/or Legacy) cost, and
## record what it reveals against the contract's seed. Refuses if already revealed or unaffordable.
## Job-Map/briefing UI then queries has_intel()/revealed_modifiers() to surface the otherwise-hidden
## modifiers, loot manifest, and silent-alarm locations (SilentAlarm.reveal() in-mission, task 06).
func buy_intel(contract: Contract, intel: IntelDef) -> bool:
	if contract == null or intel == null:
		return false
	# Nothing new to reveal → no charge.
	var already := true
	for r in intel.reveals:
		if not has_intel(contract, String(r)):
			already = false
			break
	if already:
		return false
	if take < intel.take_cost:
		return false
	if ProgressionManager != null and ProgressionManager.legacy < intel.legacy_cost:
		return false
	take -= intel.take_cost
	if ProgressionManager != null and intel.legacy_cost > 0:
		ProgressionManager.spend_legacy(intel.legacy_cost)
	var reveals: Array = []
	for r in intel.reveals:
		reveals.append(String(r))
	reveal_intel(contract, reveals)
	return true

## Mark reveal keys ("modifiers","manifest","silent_alarms") as bought for a contract's seed.
func reveal_intel(contract: Contract, reveals: Array) -> void:
	if contract == null:
		return
	var have: Array = intel_by_seed.get(contract.mission_seed, [])
	for r in reveals:
		if String(r) not in have:
			have.append(String(r))
	intel_by_seed[contract.mission_seed] = have

## Has `reveal` been bought for this contract? (Hidden-until-bought gate for the Job Map.)
func has_intel(contract: Contract, reveal: String) -> bool:
	if contract == null:
		return false
	return reveal in intel_by_seed.get(contract.mission_seed, [])

## The contract's modifier ids IF Intel has revealed them, else empty — the Job Map hides modifiers
## behind Intel (FR-13-3). Callers show "??? (buy Intel)" for the empty case.
func revealed_modifiers(contract: Contract) -> Array:
	if contract != null and has_intel(contract, "modifiers"):
		return contract.modifier_ids.duplicate()
	return []

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
	var econ := _econ()
	return heat_multiplier_for(heat, econ.heat_multiplier_base, econ.heat_multiplier_slope)

# --- The Catch: conversion → Legacy → reset (FR-12-4, FR-12-9) -------------
## The Streak ends (Caught). Convert accrued Notoriety × Heat-multiplier → permanent Legacy (floored
## for anti-frustration), bank it, announce streak_ended, then reset to a fresh low-difficulty
## Streak. Returns the Legacy awarded. Task 10's Catch handoff calls this.
func end_streak(reason: String, secured_value: int = 0) -> int:
	if challenge_mode:
		# A Catch/abort during a Challenge ends the CHALLENGE, not the real Streak: record a fail, no
		# Notoriety→Legacy conversion, no Streak reset. GameManager.goto_results restores the snapshot.
		_record_challenge({"secured_value": secured_value}, false)
		return 0
	var econ := _econ()
	var awarded := convert_to_legacy(notoriety, heat_multiplier(), econ.legacy_floor)
	# Legacy-conversion Perks (e.g. Financier: +10% Legacy from every Catch) scale the payout — closes
	# the previously-authored-but-unread `legacy_conversion_mult` modifier (task-12 per-system wiring).
	awarded = int(round(float(awarded) * (1.0 + _legacy_conversion_bonus())))
	ProgressionManager.add_legacy(awarded)
	_bump_stat(&"streaks_caught", 1)
	_bump_stat(&"legacy_earned", awarded)
	EventBus.streak_ended.emit(reason, awarded)
	# Lifetime Legacy earned just grew — a milestone arc may unlock. It's evaluated + announced on the
	# next Hideout arrival (every mission end routes through the hub), keeping this path free of the
	# milestone reward side-effect (task 20, FR-20-1). See ProgressionManager.check_milestones.
	start_new_streak()
	return awarded

## Summed +Legacy-per-Catch fraction from owned permanent Perks (Financier & friends). 0.0 if none.
func _legacy_conversion_bonus() -> float:
	if ProgressionManager != null:
		return ProgressionManager.perk_modifier_total("legacy_conversion_mult")
	return 0.0

## Per-Streak cash. A pure passthrough: each caller passes the exact Take to add — DropPoint.bank()
## passes the take-fraction *cut* of secured cash (FR-14-2, EconomyConfigDef.take_cut), the Fence
## passes a trophy's fenced value. Resets on the Catch (start_new_streak) and never converts to
## Legacy (GDD §5.3). The %-of-secured-cash rule lives at the secure site, not here, so the Fence and
## consumable refunds bank their own values undiscounted.
func add_take(amount: int) -> void:
	if amount <= 0:
		return
	take += amount

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

## Stacked performance multiplier from a flags dict + config (FR-12-1 / FR-14-3). Base ×1.0, each
## enabled bonus adds its fraction. Edge effects are applied separately (add_notoriety), never here.
## `cfg` is duck-typed: it only reads the shared `bonus_*` fields, so either an EconomyConfigDef (the
## runtime source since task 14) or a ProgressionConfigDef (task-12 tests) works.
static func stack_multiplier(flags: Dictionary, cfg) -> float:
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
