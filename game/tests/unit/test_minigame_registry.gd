extends GutTest
## Spec: the minigame tunables are data-driven — Content gained a `minigames` registry that scans the
## default MinigameConfigDef, and the Pickpocketing attribute was authored (FR-07-2, Phase 07.1).
## docs/tasks/07_minigames.md, GDD §9.8/§5.5.

func test_minigames_registry_scanned() -> void:
	assert_not_null(Content.minigames, "Content gained a minigames registry (15th)")
	assert_true(Content.minigames.has(&"default"), "default_minigame.tres scanned in by id")
	var cfg := Content.minigames.get_def(&"default") as MinigameConfigDef
	assert_not_null(cfg, "the default config resolves to a MinigameConfigDef")
	assert_gt(cfg.lockpick_arc_base_deg, 0.0, "tunables are populated")
	assert_gt(cfg.keypad_symbol_count, 1, "keypad has a symbol set")

func test_pickpocketing_attribute_exists() -> void:
	assert_true(Content.attributes.has(&"pickpocketing"), "the Pickpocketing AttributeDef is authored")
	var attr := Content.attributes.get_def(&"pickpocketing") as AttributeDef
	assert_not_null(attr)
	assert_gt(attr.effect_per_level, 0.0, "each level widens the window")
