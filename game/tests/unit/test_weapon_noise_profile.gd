extends GutTest
## Task 09 (FR-09-4): suppressed shots emit a smaller noise ring than unsuppressed — the stealth-
## critical weapon property that feeds task-04 detection. Tests the pure seam + real weapon defs + a
## suppressor attachment.

func test_shot_noise_seam_suppressed_is_smaller() -> void:
	var loud := Weapon.shot_noise_radius(24.0, false, 0.25)
	var quiet := Weapon.shot_noise_radius(24.0, true, 0.25)
	assert_lt(quiet, loud, "suppressed ring is smaller than loud")
	assert_almost_eq(quiet, 6.0, 0.001, "suppressed = base × factor")

func test_real_weapons_noise_profile() -> void:
	var pistol_def := Content.gear.get_def(&"suppressed_pistol") as GearDef
	var smg_def := Content.gear.get_def(&"smg") as GearDef
	assert_not_null(pistol_def, "gear registry populated (run --import first)")
	var pistol := Weapon.new(pistol_def)
	var smg := Weapon.new(smg_def)
	assert_lt(pistol.noise_radius(), smg.noise_radius(),
		"the suppressed pistol is quieter than the loud SMG")

func test_suppressor_attachment_reduces_noise() -> void:
	var smg_def := Content.gear.get_def(&"smg") as GearDef
	var suppressor := Content.gear.get_def(&"suppressor") as GearDef
	var smg := Weapon.new(smg_def)
	var loud := smg.noise_radius()
	smg.attach(suppressor)
	assert_lt(smg.noise_radius(), loud, "a suppressor lowers the SMG's noise ring")
	assert_true(&"suppressor" in smg.mods(), "attachment is recorded")

func test_fire_spends_ammo_and_recoil_bleeds() -> void:
	var smg_def := Content.gear.get_def(&"smg") as GearDef
	var smg := Weapon.new(smg_def)
	var cap := smg.ammo
	var shot := smg.fire()
	assert_false(shot.is_empty(), "a loaded weapon fires")
	assert_eq(smg.ammo, cap - 1, "one round spent")
	assert_gt(smg.recoil(), 0.0, "recoil accumulates on firing")
	smg.tick(2.0)
	assert_almost_eq(smg.recoil(), 0.0, 0.001, "recoil bleeds off over time")
