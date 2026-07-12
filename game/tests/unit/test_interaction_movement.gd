extends GutTest
## Spec (misc-fixes-5): a CHANNELLED interaction — a timed hack, a hold-to-interact — needs you to stand
## still, and the player chooses what moving does about it (Options > Controls > "While Interacting",
## stored as gameplay/interaction_movement):
##   • CANCEL (0) — trying to move abandons the interaction outright.
##   • LOCK   (1) — you're rooted in place until it finishes; pressing interact again cancels.
## A running BREACH is exempt from both (see test_breach_proximity.gd): it reports is_channeling() == false.
## docs/tasks/03_player_controller_camera.md (FR-03-5), 06_heist_mechanics_obstacles.md (FR-06-5).

const CANCEL := PlayerController.InteractionMovement.CANCEL
const LOCK := PlayerController.InteractionMovement.LOCK

var _player: PlayerController

func before_each() -> void:
	_player = PlayerController.new()
	_player.config = PlayerConfigDef.new()

func after_each() -> void:
	_player.free()

func _hack() -> HackTarget:
	var d := ObstacleDef.new()
	d.id = &"test_hack"
	d.category = ObstacleDef.Category.HACK_TARGET
	d.time_seconds = 3.0
	d.proximity_range = 3.0
	d.params = {"device": "elock"}
	var h: HackTarget = add_child_autofree(HackTarget.new())
	h.def = d
	return h

# --- The rule itself (pure seams) -------------------------------------------

func test_cancel_mode_only_cancels_when_actually_moving() -> void:
	assert_true(PlayerController.cancels_on_move(CANCEL, true, true), "interacting + moving = cancelled")
	assert_false(PlayerController.cancels_on_move(CANCEL, true, false), "standing still keeps the interaction")
	assert_false(PlayerController.cancels_on_move(CANCEL, false, true), "moving with nothing running is just walking")

func test_lock_mode_never_cancels_on_movement() -> void:
	assert_false(PlayerController.cancels_on_move(LOCK, true, true),
		"in LOCK mode you CAN'T move, so movement must never be read as a cancel")

func test_only_lock_mode_roots_the_player() -> void:
	assert_true(PlayerController.locks_movement(LOCK, true), "rooted while interacting")
	assert_false(PlayerController.locks_movement(LOCK, false), "free to walk when nothing is running")
	assert_false(PlayerController.locks_movement(CANCEL, true), "CANCEL mode never roots you — it cancels instead")

# --- The channel contract ----------------------------------------------------

func test_a_running_hack_is_a_channel_a_finished_one_is_not() -> void:
	var h := _hack()
	assert_false(h.is_channeling(), "an untouched lock is not a channel")
	h.begin_hack(null)
	assert_true(h.is_channeling(), "a timed hack is exactly the interaction the movement rule governs")
	h.tick(3.0, 1.0)   # stood there through the whole fill
	assert_true(h.solved)
	assert_false(h.is_channeling(), "a completed hack is no longer a channel — movement is free again")

func test_cancel_interaction_abandons_the_hack() -> void:
	var h := _hack()
	h.begin_hack(null)
	h.tick(2.0, 1.0)
	h.cancel_interaction()   # the seam PlayerController calls when you move (or press interact in LOCK mode)
	assert_false(h.hacking, "the hack is abandoned")
	assert_almost_eq(h.progress, 0.0, 0.0001, "and its progress is lost — you start over")
	assert_false(h.solved)

# --- Wired through the player -------------------------------------------------

func test_the_player_tracks_a_tap_started_channel() -> void:
	var h := _hack()
	assert_false(_player.interaction_active(), "nothing running")
	_player._current_interactable = h
	assert_true(_player.update_hold(0.0, true), "an instant tap fires")
	h.begin_hack(_player)
	_player._channel = h
	assert_true(_player.interaction_active(), "the tap-started hack keeps the player 'interacting'")

	# Looking away must NOT end it — the hack is still filling, so the rule still applies.
	_player._current_interactable = null
	assert_true(_player.interaction_active(), "a channel outlives the aim target")

	_player.cancel_interaction()
	assert_false(h.hacking, "the player's cancel reaches the obstacle")
	assert_false(_player.interaction_active(), "and clears its own channel")

func test_a_hold_to_interact_counts_as_interacting_while_charging() -> void:
	var hold := Interactable.new()
	hold.hold_seconds = 0.5
	_player._current_interactable = hold
	assert_false(_player.interaction_active(), "not yet — the key hasn't gone down")
	_player.update_hold(0.2, true)
	assert_true(_player.interaction_active(), "charging a hold is an interaction the movement rule governs")
	_player.cancel_interaction()
	assert_false(_player.interaction_active(), "cancelling drops the charge")
	assert_false(_player.update_hold(0.2, true),
		"and a still-held key can't instantly restart what was just cancelled — release re-arms it")
	_player._current_interactable = null
	hold.free()

func test_cancelling_under_a_held_key_does_not_instantly_restart() -> void:
	# The LOCK-mode cancel press happens with the interact key DOWN. A hack is an instant-tap target
	# (hold_seconds == 0), so without latching the hold timer, update_hold() would fire again on the very
	# next frame and restart the hack we were just asked to abandon.
	var h := _hack()
	_player._current_interactable = h
	assert_true(_player.update_hold(0.0, true), "the tap starts it")
	h.begin_hack(_player)
	_player._channel = h

	_player.cancel_interaction()          # ...pressed interact to cancel; the key is still down
	assert_false(h.hacking, "cancelled")
	assert_false(_player.update_hold(0.0, true), "a still-held key must NOT re-fire interact()")
	assert_false(_player.update_hold(0.0, false), "releasing re-arms without firing")
	assert_true(_player.update_hold(0.0, true), "and a fresh press starts it over, as normal")
	_player._current_interactable = null

func test_the_cancel_prompt_is_lock_mode_and_channels_only() -> void:
	var h := _hack()
	h.begin_hack(null)
	_player._channel = h

	_player._interaction_movement = CANCEL
	assert_false(_player.interaction_locked(), "CANCEL mode leaves you free to walk (and lose the hack)")
	assert_false(_player.interaction_cancel_prompt(), "so there's nothing to 'press to cancel'")

	_player._interaction_movement = LOCK
	assert_true(_player.interaction_locked(), "LOCK mode roots you for the duration")
	assert_true(_player.interaction_cancel_prompt(), "and the interact key becomes the way out")
