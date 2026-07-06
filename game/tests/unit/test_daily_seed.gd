extends GutTest
## Task 20 (FR-20-2): the same date yields the same daily/weekly Challenge for everyone. LiveOps derives
## the seed from a self-rolled stable hash (NOT Godot's hash(), which isn't cross-platform stable), and
## LiveOps.challenge_contract turns that seed into a reproducible Contract. See docs/tasks/20_progression_milestones.md.

const EPOCH := 1704067200   # 2024-01-01 UTC — the manifest's rotation/day epoch

func test_daily_seed_is_deterministic_within_a_day() -> void:
	var morning := EPOCH + 5 * 86400 + 3600          # day 5, 01:00
	var evening := EPOCH + 5 * 86400 + 22 * 3600      # day 5, 22:00 (same UTC day)
	assert_eq(LiveOps.daily_seed(morning), LiveOps.daily_seed(morning), "pure/deterministic")
	assert_eq(LiveOps.daily_seed(morning), LiveOps.daily_seed(evening), "same UTC day → same daily seed")

func test_daily_seed_differs_across_days() -> void:
	var d5 := LiveOps.daily_seed(EPOCH + 5 * 86400)
	var d6 := LiveOps.daily_seed(EPOCH + 6 * 86400)
	assert_ne(d5, d6, "consecutive days produce different daily seeds")
	assert_gt(d5, 0, "seed is a positive 31-bit int (safe for RNG.seed / mission_seed)")

func test_weekly_seed_buckets_by_seven_days() -> void:
	# Weekly buckets are absolute 7-day windows (floor(day_index / 7)); pick a 7-aligned start so the
	# window boundaries are unambiguous. 19740 % 7 == 0.
	var t := 19740 * 86400
	assert_eq(LiveOps.weekly_seed(t), LiveOps.weekly_seed(t + 6 * 86400), "all 7 days of a bucket → same weekly seed")
	assert_ne(LiveOps.weekly_seed(t), LiveOps.weekly_seed(t + 7 * 86400), "the next bucket rotates the weekly seed")

func test_challenge_contract_is_reproducible_for_a_seed() -> void:
	# Everyone on the same date shares the same Contract fingerprint (FR-20-2). Uses a real generatable
	# archetype so the objective/modifier draw resolves against Content.
	var seed := LiveOps.daily_seed(EPOCH + 5 * 86400)
	var a := LiveOps.challenge_contract(seed, ["bank"], "daily", 3)
	var b := LiveOps.challenge_contract(seed, ["bank"], "daily", 3)
	assert_eq(a.to_dict(), b.to_dict(), "same seed + pool → identical Contract")
	assert_eq(a.archetype_id, &"bank", "picks from the candidate pool")
	assert_eq(a.mission_seed, seed, "the Contract carries the date seed")
	assert_true(String(a.objective_id) != "", "resolves a real objective from the archetype")

func test_challenge_contract_differs_across_days() -> void:
	var c5 := LiveOps.challenge_contract(LiveOps.daily_seed(EPOCH + 5 * 86400), ["bank"], "daily", 3)
	var c6 := LiveOps.challenge_contract(LiveOps.daily_seed(EPOCH + 6 * 86400), ["bank"], "daily", 3)
	assert_ne(c5.mission_seed, c6.mission_seed, "different days → different mission seed")

func test_stable_hash_is_canonical_fnv1a() -> void:
	# Spec anchor: the derivation must not drift (a changed algorithm would desync every player's daily).
	for s in ["daily:0", "weekly:12", "daily:20275", "nine-lives"]:
		assert_eq(LiveOps.stable_hash(s), _fnv1a(s), "stable_hash stays canonical 31-bit FNV-1a for '%s'" % s)

func _fnv1a(s: String) -> int:
	var h := 2166136261
	for i in s.length():
		h = (h ^ s.unicode_at(i)) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	return h & 0x7FFFFFFF
