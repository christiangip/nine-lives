extends GutTest
## Spec: PlayerController's carry-backed methods satisfy the duck-typed bridges task 06 wrote
## against (Obstacle.actor_has_item, BiometricLock's is_carrying_keyholder) — closes the
## TODO[08] hooks with a real assertion instead of manual trust. docs/tasks/08_loot_inventory.md
## (↩ from 06).

func test_obstacle_actor_has_item_resolves_through_player_inventory() -> void:
	var player: PlayerController = autofree(PlayerController.new())
	player.inventory = Inventory.new()
	player.inventory.add_item(&"vault_keycard")
	assert_true(Obstacle.actor_has_item(player, &"vault_keycard"))
	assert_false(Obstacle.actor_has_item(player, &"unrelated_id"))

func test_biometric_lock_keyholder_duck_type_resolves() -> void:
	var player: PlayerController = autofree(PlayerController.new())
	player.inventory = Inventory.new()
	var body: Body = autofree(Body.new())
	body.carried_item = &"cfo_biometrics"
	player.inventory.pick_up_body(body)
	assert_true(player.is_carrying_keyholder(&"cfo_biometrics"))

func test_no_inventory_means_no_items() -> void:
	var player: PlayerController = autofree(PlayerController.new())
	assert_false(player.has_item(&"vault_keycard"))
	assert_false(player.is_carrying_keyholder(&"cfo_biometrics"))
	assert_false(Obstacle.actor_has_item(player, &"vault_keycard"))
