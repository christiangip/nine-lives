extends GutTest
## Task 11 canary: the mission-generation content authored as .tres loaded cleanly and hydrated. Catches
## a mistyped Array[Dictionary]/Array[StringName] .tres before the generator tests run on empty data.

func test_sections_registry_scanned_in() -> void:
	assert_not_null(Content.sections, "Content gained the 18th registry (sections)")
	for id in [&"bank_entry_lobby", &"bank_office", &"bank_teller_hall", &"bank_server_room", &"bank_vault", &"bank_loading_dock"]:
		assert_true(Content.sections.has(id), "section '%s' scanned in" % id)

func test_section_anchors_hydrated() -> void:
	var vault := Content.sections.get_def(&"bank_vault") as SectionDef
	assert_not_null(vault, "bank_vault is a SectionDef")
	assert_eq(vault.kind, SectionDef.Kind.OBJECTIVE, "vault kind hydrated from the .tres")
	assert_true(vault.anchors.size() > 0, "vault anchors (Array[Dictionary]) hydrated from the .tres")
	assert_true(vault.has_anchor(&"objective"), "vault declares an objective anchor")
	var lobby := Content.sections.get_def(&"bank_entry_lobby") as SectionDef
	assert_eq(lobby.anchor_count(&"entry"), 2, "entry lobby declares two doors (alt entry)")

func test_archetypes_hydrated() -> void:
	for id in [&"bank", &"museum", &"warehouse"]:
		assert_true(Content.archetypes.has(id), "archetype '%s' scanned in" % id)
	var bank := Content.archetypes.get_def(&"bank") as ArchetypeDef
	assert_true(bank.section_ids.size() >= 4, "bank section_ids (Array[StringName]) hydrated")
	assert_true(bank.objective_ids.has(&"crack_vault"), "bank objective pool hydrated")
	assert_true(bank.enemy_roster.has(&"inspector"), "bank fields the Inspector (vault keycard carrier)")

func test_objectives_and_modifiers() -> void:
	for id in [&"grab_value", &"mark_high_value", &"crack_vault", &"retrieve_deliver", &"sabotage_server", &"puzzle_room"]:
		assert_true(Content.objectives.has(id), "objective '%s'" % id)
	for id in [&"extra_patrols", &"blackout", &"silent_alarm_heavy", &"tight_security"]:
		assert_true(Content.modifiers.has(id), "modifier '%s'" % id)

func test_all_three_archetypes_generatable() -> void:
	assert_true(MissionBoard.generatable_archetypes().size() >= 3, "bank/museum/warehouse all generate")
