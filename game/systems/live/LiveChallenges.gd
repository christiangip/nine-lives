extends RefCounted
class_name LiveChallenges
## Local best-time/score records for the daily/weekly Challenges (task 20, FR-20-2). Persisted OUTSIDE
## the 10 save slots in user://challenge_results.json (like PackManager's packs.json), keyed by the
## date-derived seed, so a disabled/corrupt save can never touch the leaderboard and Challenges stay a
## parallel, leaderboard-ready track. Pure-ish static; the better_result fold is a pure seam and a
## configure()/reset() test hook (mirrors PackManager) keeps CI off the player's real records.
## See docs/tasks/20_progression_milestones.md.

const DEFAULT_PATH := "user://challenge_results.json"

static var _path := DEFAULT_PATH

# --- Test seam -------------------------------------------------------------
## Point the store at a temp file so tests/sandbox never touch the player's real records.
static func configure(path: String) -> void:
	_path = path

static func reset() -> void:
	_path = DEFAULT_PATH

# --- I/O -------------------------------------------------------------------
static func _read_all() -> Dictionary:
	if not FileAccess.file_exists(_path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path))
	return data if data is Dictionary else {}

static func _write_all(d: Dictionary) -> void:
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "\t"))
		f.close()

# --- Public API ------------------------------------------------------------
## The recorded best for a seed, or {} if never played. Keys: best_seconds, best_score, completed, plays, kind.
static func best_for(seed: int) -> Dictionary:
	return _read_all().get(str(seed), {})

## Whether this seed's Challenge has ever been completed (gates the one-time Legacy reward).
static func is_completed(seed: int) -> bool:
	return bool(best_for(seed).get("completed", false))

## Record a Challenge attempt and keep the best. Returns the merged record. A Catch (success=false)
## still counts a play but never sets `completed` or a best time.
static func record(seed: int, kind: String, elapsed: float, secured: int, success: bool) -> Dictionary:
	var all := _read_all()
	var key := str(seed)
	var prev: Dictionary = all.get(key, {})
	var attempt := {
		"kind": kind,
		"seconds": elapsed,
		"score": secured,
		"success": success,
	}
	var merged := better_result(prev, attempt)
	merged["plays"] = int(prev.get("plays", 0)) + 1
	merged["kind"] = kind
	all[key] = merged
	_write_all(all)
	return merged

## Pure: fold a new attempt into the stored best. Lower time & higher score win; `completed` latches
## true once any attempt succeeds. Headless-testable (no disk, no autoloads).
static func better_result(prev: Dictionary, attempt: Dictionary) -> Dictionary:
	var out := prev.duplicate()
	var success := bool(attempt.get("success", false))
	out["completed"] = bool(prev.get("completed", false)) or success
	if success:
		var secs := float(attempt.get("seconds", 0.0))
		if not prev.has("best_seconds") or secs < float(prev.get("best_seconds")):
			out["best_seconds"] = secs
		var score := int(attempt.get("score", 0))
		if score > int(prev.get("best_score", 0)):
			out["best_score"] = score
	return out
