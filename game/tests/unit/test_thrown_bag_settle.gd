extends GutTest
## Spec (misc-fixes-4 issue 1): a thrown projectile's landing resolves EXACTLY ONCE.
##
## queue_free() is deferred, so a ThrownBag stays alive and contact-monitoring for the rest of the
## frame after it lands — and _settle() spawns a DroppedBag whose own StaticBody3D materialises
## inside the still-live projectile's collider. Without a latch that reported as another contact
## (as did any second level chunk — the world is built from many separate StaticBody3Ds), _settle()
## ran again, and every duplicate DroppedBag got handed the SAME Bag RefCounted. Each one could then
## be reclaimed for full value: infinite loot.
##
## These tests drive _on_body_entered() directly — the handler is a plain method, so the once-only
## rule is provable with ZERO physics simulation, matching test_throw_to_drop.gd's approach.
## docs/tasks/08_loot_inventory.md (FR-08-4).

class StubCarrier extends Node3D:
	var inventory: Inventory = Inventory.new()

func _bag(value: int = 18000) -> Bag:
	var gold := TestHelper.make_loot(12.4, 0.6, value)
	gold.needs_bagging = true
	var b := Bag.new()
	b.add(gold)
	return b

func _host() -> Node3D:
	return add_child_autofree(Node3D.new()) as Node3D

## A ThrownBag mid-flight, parented under `host` and carrying `bag`.
func _thrown(host: Node3D, bag: Bag, inv: Inventory) -> ThrownBag:
	var t := ThrownBag.new()
	t.bag = bag
	t.thrower_inventory = inv
	host.add_child(t)
	return t

func _dropped_bags(host: Node3D) -> Array:
	var out: Array = []
	for c in host.get_children():
		if c is DroppedBag:
			out.append(c)
	return out

# --- The duplication itself ------------------------------------------------

func test_landing_twice_spawns_only_one_dropped_bag() -> void:
	var host := _host()
	var inv := Inventory.new()
	var thrown := _thrown(host, _bag(), inv)

	var floor_a: StaticBody3D = autofree(StaticBody3D.new())
	var floor_b: StaticBody3D = autofree(StaticBody3D.new())
	thrown._on_body_entered(floor_a)   # hits the floor
	thrown._on_body_entered(floor_b)   # ...and a wall in the same physics step

	assert_eq(_dropped_bags(host).size(), 1,
		"a bag reporting two contacts in one frame must settle ONCE — two DroppedBags sharing one Bag was the infinite-loot loop")

func test_the_settled_bag_carries_the_value_exactly_once() -> void:
	var host := _host()
	var inv := Inventory.new()
	var thrown := _thrown(host, _bag(18000), inv)
	thrown._on_body_entered(autofree(StaticBody3D.new()))
	thrown._on_body_entered(autofree(StaticBody3D.new()))

	var carrier: StubCarrier = add_child_autofree(StubCarrier.new())
	carrier.inventory = inv
	for d in _dropped_bags(host):
		d.interact(carrier)
	assert_eq(inv.in_hand_value(), 18000, "reclaiming every bag left in the world credits the value once, not twice")

# --- Drop Point banking ----------------------------------------------------

func test_landing_in_a_drop_point_banks_once() -> void:
	var host := _host()
	var inv := Inventory.new()
	var thrown := _thrown(host, _bag(18000), inv)
	var drop: DropPoint = autofree(DropPoint.new())

	thrown._on_body_entered(drop)
	thrown._on_body_entered(drop)   # a second contact with the same Drop Point

	assert_eq(inv.secured_value(), 18000, "a bag landing in a Drop Point banks its value once, not per contact")
	assert_eq(_dropped_bags(host).size(), 0, "a banked bag leaves nothing reclaimable behind")

func test_floor_then_drop_point_resolves_as_one_outcome() -> void:
	var host := _host()
	var inv := Inventory.new()
	var thrown := _thrown(host, _bag(18000), inv)
	var drop: DropPoint = autofree(DropPoint.new())

	thrown._on_body_entered(autofree(StaticBody3D.new()))   # clips the floor first...
	thrown._on_body_entered(drop)                           # ...then the Drop Point, same step

	assert_eq(inv.secured_value(), 0, "the landing already resolved as a settle — it must not ALSO bank")
	assert_eq(_dropped_bags(host).size(), 1, "exactly one outcome: the bag is on the floor, not banked AND on the floor")

# --- DroppedBag reclaim is once-only ---------------------------------------

func test_reclaiming_a_dropped_bag_twice_credits_it_once() -> void:
	var host := _host()
	var dropped: DroppedBag = DroppedBag.new()
	dropped.bag = _bag(18000)
	host.add_child(dropped)

	var carrier: StubCarrier = add_child_autofree(StubCarrier.new())
	dropped.interact(carrier)
	assert_eq(carrier.inventory.in_hand_value(), 18000, "the first reclaim adopts the bag")

	dropped.interact(carrier)   # deferred queue_free: the node is still interactable this frame
	assert_eq(carrier.inventory.in_hand_value(), 18000, "a second interact in the same frame must be a no-op")
	assert_false(dropped.can_interact(carrier), "a reclaimed bag stops offering its prompt")

# --- The body projectile shares the same latch ------------------------------

func test_a_thrown_body_lands_once() -> void:
	var host := _host()
	var thrown := ThrownBody.new()
	var body: Body = Body.new()
	thrown.body = body
	host.add_child(thrown)

	thrown._on_body_entered(autofree(StaticBody3D.new()))
	thrown._on_body_entered(autofree(StaticBody3D.new()))   # a second contact would re-parent an already-parented Body

	assert_eq(body.get_parent(), host, "the body is deposited into the world")
	var bodies: Array = []
	for c in host.get_children():
		if c is Body:
			bodies.append(c)
	assert_eq(bodies.size(), 1, "the body is deposited exactly once")
