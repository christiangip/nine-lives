extends RefCounted
class_name LiveOps
## Live-ops seams (task 20): date→seed derivation, the rotating global modifier, the active season, and
## the daily/weekly Challenge contract. Pure static + time-injectable (every date call takes a Unix
## timestamp, defaulting to system time) so it's headless-deterministic. Reads the single live manifest
## game/data/liveops.json DIRECTLY as a raw Dictionary (config()) — not hydrated into a typed def — so
## its nested arrays/objects load cleanly and the whole file is directly swappable for a fetched remote
## manifest later (FR-20-6, remote-tolerant). Reached as the global `LiveOps` (like PackManager/Services);
## NO 11th autoload — the architecture stays at 10. See docs/tasks/20_progression_milestones.md, docs/LIVE_OPS.md.

const CONFIG_PATH := "res://game/data/liveops.json"
const SECONDS_PER_DAY := 86400

# --- Config ----------------------------------------------------------------
## The live manifest as a raw Dictionary; {} if missing/unparseable (callers use .get with defaults so
## nothing crashes). A path override lets the sandbox/tests point elsewhere without touching the real file.
static func config(path: String = CONFIG_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

# --- Date → seed (stable across machines/versions) -------------------------
## A deterministic 31-bit FNV-1a hash of a string. Self-rolled ON PURPOSE: Godot's built-in hash() is
## not guaranteed stable across platforms/versions, but a daily/weekly seed must be identical for
## everyone (FR-20-2). Masked positive so it round-trips cleanly through JSON / RNG.seed / mission_seed.
static func stable_hash(s: String) -> int:
	var h := 2166136261
	for i in s.length():
		h = (h ^ s.unicode_at(i)) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	return h & 0x7FFFFFFF

static func now_unix() -> int:
	return int(Time.get_unix_time_from_system())

## Whole-day index since the Unix epoch (UTC) — the stable key a daily seed derives from.
static func day_index(ts: int) -> int:
	return int(floor(float(ts) / float(SECONDS_PER_DAY)))

## Whole-week index since the epoch (7-day buckets).
static func week_index(ts: int) -> int:
	return int(floor(float(day_index(ts)) / 7.0))

## The daily Challenge seed for a timestamp (default = now). Identical for everyone on the same UTC day.
static func daily_seed(ts: int = -1) -> int:
	return stable_hash("daily:%d" % day_index(ts if ts >= 0 else now_unix()))

## The weekly Challenge seed for a timestamp (default = now). Identical for everyone in the same week.
static func weekly_seed(ts: int = -1) -> int:
	return stable_hash("weekly:%d" % week_index(ts if ts >= 0 else now_unix()))

## A short YYYY-MM-DD label for the day a timestamp falls in (UI).
static func day_label(ts: int = -1) -> String:
	var d := Time.get_datetime_dict_from_unix_time(ts if ts >= 0 else now_unix())
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

# --- Rotating global modifiers (FR-20-3) -----------------------------------
## The global modifier id(s) active for a timestamp, from config.modifier_rotation. The rotation is a
## ring of `slots`, each active for `period_days`; an empty-string slot is a calm week → []. Applied
## board-wide: RunManager.refresh_board appends these to every contract's modifier_ids, flowing through
## the existing MissionPopulator._merged_effects with zero populator changes.
static func active_modifiers(cfg: Dictionary, ts: int = -1) -> Array:
	var t := ts if ts >= 0 else now_unix()
	var rot: Dictionary = cfg.get("modifier_rotation", {})
	var slots: Array = rot.get("slots", [])
	if slots.is_empty():
		return []
	var epoch := int(rot.get("epoch_unix", 0))
	var period := maxi(1, int(rot.get("period_days", 7)))
	var elapsed_days := maxi(0, day_index(t) - day_index(epoch))
	@warning_ignore("integer_division")
	var idx := (elapsed_days / period) % slots.size()
	var mid := StringName(slots[idx])
	return [mid] if String(mid) != "" else []

# --- Seasonal goals (FR-20-4) ----------------------------------------------
## The season whose [start_unix, start_unix + duration_days) window contains the timestamp, as a raw
## Dictionary (its goals feed the Live Board + reward grants). {} if none is active.
static func active_season(cfg: Dictionary, ts: int = -1) -> Dictionary:
	var t := ts if ts >= 0 else now_unix()
	for s in cfg.get("seasons", []):
		if s is Dictionary:
			var start := int(s.get("start_unix", 0))
			var end := start + int(s.get("duration_days", 0)) * SECONDS_PER_DAY
			if t >= start and t < end:
				return s
	return {}

# --- Daily/weekly Challenge contract (FR-20-2) -----------------------------
## Build the deterministic daily/weekly Challenge contract from a date-derived seed. Same seed + the
## same candidate pool → identical Contract (mission_seed = seed), so everyone's Challenge is the same.
## Picks archetype/objective/modifier like MissionBoard, reading Content for the chosen archetype's
## pools when available. `archetype_ids` is the caller-supplied candidate pool (generatable ids,
## optionally config-filtered); the pool is sorted so the pick is order-independent.
static func challenge_contract(seed: int, archetype_ids: Array, kind: String, tier: int = 3) -> Contract:
	var c := Contract.new()
	c.mission_seed = seed
	c.tier = clampi(tier, 1, 5)
	c.difficulty = c.tier * 2
	if archetype_ids.is_empty():
		return c
	var pool: Array = []
	for a in archetype_ids:
		pool.append(String(a))
	pool.sort()   # order-independent pick for a given seed + set
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	c.archetype_id = StringName(pool[rng.randi_range(0, pool.size() - 1)])
	var arch := _archetype(c.archetype_id)
	if arch != null:
		if not arch.objective_ids.is_empty():
			c.objective_id = arch.objective_ids[rng.randi_range(0, arch.objective_ids.size() - 1)]
		if not arch.modifier_pool.is_empty():
			var mods := arch.modifier_pool.duplicate()
			c.modifier_ids = [mods[rng.randi_range(0, mods.size() - 1)]] as Array[StringName]
	return c

## The candidate archetype pool for a Challenge: every currently-generatable archetype id, narrowed to
## a config allow-list when one is given (empty list = any generatable). Runtime helper (reads Content).
static func challenge_candidates(cfg: Dictionary, kind: String) -> Array:
	var allow: Array = cfg.get(("daily_archetypes" if kind == "daily" else "weekly_archetypes"), [])
	var out: Array = []
	for a in MissionBoard.generatable_archetypes():
		var aid := String((a as ArchetypeDef).id)
		if allow.is_empty() or aid in allow:
			out.append(aid)
	return out

static func _archetype(id: StringName) -> ArchetypeDef:
	if Content != null and Content.archetypes != null:
		return Content.archetypes.get_def(id) as ArchetypeDef
	return null
