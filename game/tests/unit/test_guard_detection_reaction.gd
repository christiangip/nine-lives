extends GutTest
## Spec: the guard reacts to its OWN DetectionSensor's `detection_changed` by *escalating only* —
## a rising meter promotes it, but a decaying meter (the norm once the player is lost) must NOT
## interrupt an in-progress investigate/search; those wind down on their own timers. This guards
## the FR-05-1 "investigate → local search → resume" loop against the decay-downgrade override,
## which the pure-seam tests can't see. docs/tasks/05_ai_actors.md.

const AI := GuardAI.AIState
const S := DetectionSensor.DetectionState

var _guard: GuardAI
var _sensor: DetectionSensor

func before_each() -> void:
	_guard = GuardAI.new()
	_sensor = DetectionSensor.new()
	_guard.add_child(_sensor)          # _resolve_sensor picks it up in _ready
	_guard.ai_config = AIConfigDef.new()
	add_child_autofree(_guard)         # runs _ready (resolve sensor + connect signals); no frames advance

func _feed(det_state: int) -> void:
	# Drive the live signal handler directly with our own sensor's id.
	_guard._on_detection_changed(_sensor.get_instance_id(), det_state, 0.0)

# --- The bug this file exists for ------------------------------------------
func test_decay_downgrade_does_not_interrupt_search() -> void:
	_guard._set_ai_state(AI.SEARCH)
	_feed(S.SUSPICIOUS)   # one decay step SEARCHING→SUSPICIOUS while the player is lost
	assert_eq(_guard.ai_state, AI.SEARCH, "a decaying meter must not yank the guard out of its search")

func test_full_decay_keeps_search_until_timer() -> void:
	_guard._set_ai_state(AI.SEARCH)
	_feed(S.UNAWARE)      # meter fully decayed
	assert_eq(_guard.ai_state, AI.SEARCH, "SEARCH ends on its own timer, not on the meter emptying")

func test_investigate_survives_decay_too() -> void:
	_guard._set_ai_state(AI.INVESTIGATE)
	_feed(S.UNAWARE)
	assert_eq(_guard.ai_state, AI.INVESTIGATE, "a decay step doesn't abort an in-progress investigate")

# --- Escalation still works ------------------------------------------------
func test_suspicion_escalates_patrol_to_investigate() -> void:
	assert_eq(_guard.ai_state, AI.PATROL, "starts on patrol")
	_feed(S.SUSPICIOUS)
	assert_eq(_guard.ai_state, AI.INVESTIGATE, "a fresh half-sighting sends the guard to investigate")

func test_searching_routes_through_investigate_not_straight_to_search() -> void:
	_feed(S.SEARCHING)
	assert_eq(_guard.ai_state, AI.INVESTIGATE,
		"a lead first walks the guard to the contact (INVESTIGATE) before it sweeps — never search-in-place")

func test_spot_escalates_to_combat() -> void:
	_guard._set_ai_state(AI.INVESTIGATE)
	_feed(S.ALERTED)
	assert_eq(_guard.ai_state, AI.COMBAT, "a confirmed spot overrides a lesser lead")

func test_combat_latches_against_decay() -> void:
	_guard._set_ai_state(AI.COMBAT)
	_feed(S.UNAWARE)
	assert_eq(_guard.ai_state, AI.COMBAT, "once committed to combat, a decaying meter doesn't stand the guard down")

# --- Supporting pure seams --------------------------------------------------
func test_behavior_severity_orders_states() -> void:
	assert_lt(_guard.behavior_severity(AI.PATROL), _guard.behavior_severity(AI.INVESTIGATE), "patrol < investigate")
	assert_lt(_guard.behavior_severity(AI.INVESTIGATE), _guard.behavior_severity(AI.SEARCH), "investigate < search")
	assert_lt(_guard.behavior_severity(AI.SEARCH), _guard.behavior_severity(AI.COMBAT), "search < combat")

func test_search_offset_rings_the_center_at_radius() -> void:
	assert_almost_eq(_guard.search_offset(0, 4.0).length(), 4.0, 0.001, "sweep points sit at search_radius")
	assert_eq(_guard.search_offset(0, 4.0).y, 0.0, "sweep stays on the floor plane")
	assert_ne(_guard.search_offset(0, 4.0), _guard.search_offset(1, 4.0), "successive sweep points differ")
