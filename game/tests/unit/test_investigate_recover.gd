extends GutTest
## Spec: detection states drive the guard's behavior — a half-sighting/noise sends it to
## investigate the last-known spot, a found-evidence state to a local search, and finding
## nothing returns it to patrol (FR-05-1, Phase 05.1). docs/tasks/05_ai_actors.md.

const AI := GuardAI.AIState
const S := DetectionSensor.DetectionState

var _g: GuardAI

func before_each() -> void:
	_g = GuardAI.new()

func after_each() -> void:
	_g.free()

func test_detection_maps_to_behaviour() -> void:
	assert_eq(_g.ai_state_for_detection(S.UNAWARE), AI.PATROL, "calm guard patrols")
	assert_eq(_g.ai_state_for_detection(S.SUSPICIOUS), AI.INVESTIGATE, "a half-sighting/noise → investigate")
	assert_eq(_g.ai_state_for_detection(S.SEARCHING), AI.SEARCH, "found evidence → local search")
	assert_eq(_g.ai_state_for_detection(S.ALERTED), AI.COMBAT, "confirmed spot → combat/converge")
	assert_eq(_g.ai_state_for_detection(S.PURSUIT), AI.COMBAT, "pursuit stays in combat")

func test_investigate_to_search_on_arrival() -> void:
	assert_eq(_g.investigate_next(true, false), AI.SEARCH, "arriving at the last-known spot starts a local search")

func test_investigate_gives_up_on_timeout() -> void:
	assert_eq(_g.investigate_next(false, true), AI.PATROL, "a stale lead that never resolves returns to patrol")

func test_investigate_keeps_going_until_resolved() -> void:
	assert_eq(_g.investigate_next(false, false), AI.INVESTIGATE, "still walking toward the lead")

func test_search_resumes_patrol_when_clear() -> void:
	assert_eq(_g.search_next(true), AI.PATROL, "finding nothing resumes patrol")
	assert_eq(_g.search_next(false), AI.SEARCH, "keeps sweeping until the search window elapses")

func test_timer_counts_down_and_floors() -> void:
	assert_almost_eq(_g.tick_timer(1.0, 0.3), 0.7, 0.0001, "the per-state timer counts down")
	assert_eq(_g.tick_timer(0.2, 0.5), 0.0, "and floors at zero (never negative)")
