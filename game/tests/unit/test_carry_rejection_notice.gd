extends GutTest
## Spec (misc-fixes-3 issue 4): a pickup refused by the two-axis carry cap must SAY SO. LootPickup already
## emitted a local pickup_rejected(axis); nothing listened, so the item just silently stayed in the world.
## The HUD now toasts the failing axis. docs/tasks/08_loot_inventory.md (FR-08-1), docs/tasks/15_ui_hud_menus.md.

func test_carry_message_names_the_failing_axis() -> void:
	assert_eq(MissionHUD.carry_message(&"weight"), "You are carrying too much weight")
	assert_eq(MissionHUD.carry_message(&"volume"), "No space — you can't carry that")
	assert_eq(MissionHUD.carry_message(&"hands"), "Your hands are full")

func test_a_rejected_pickup_toasts_on_the_hud() -> void:
	var packed := load("res://game/scenes/ui/hud/HUD.tscn") as PackedScene
	var hud: MissionHUD = packed.instantiate()
	add_child_autofree(hud)
	var pickup: LootPickup = add_child_autofree(LootPickup.new())
	hud._on_interaction_target_changed(pickup)   # the player aims at the loot
	pickup.pickup_rejected.emit(&"volume")       # …and the bag is full
	assert_eq(hud._notice_label.text, "No space — you can't carry that",
		"the HUD explains WHY the pickup failed")

func test_a_freed_target_does_not_break_the_binding() -> void:
	# A SUCCESSFUL pickup queue_free()s the target, and the aim then changes to null: the disconnect
	# must not touch the freed object.
	var packed := load("res://game/scenes/ui/hud/HUD.tscn") as PackedScene
	var hud: MissionHUD = packed.instantiate()
	add_child_autofree(hud)
	var pickup := LootPickup.new()
	add_child(pickup)
	hud._on_interaction_target_changed(pickup)
	pickup.free()
	hud._on_interaction_target_changed(null)
	assert_null(hud._reject_src, "the stale binding is dropped safely")
