extends RefCounted
class_name Haptics
## Gamepad rumble helper (task 21, FR-21-1 accessibility). A thin, gated wrapper over
## Input.start_joy_vibration so feedback sites (fire / take damage / alarm) don't each re-check the setting or
## hard-code device ids. Honours gameplay/vibration; no-ops headlessly or with no pad connected. Impulse
## specs are named presentation constants (like UITheme's palette / NoiseRingSpawner's timings) — not gameplay
## tunables. Pure gate. See docs/tasks/21_release_polish.md and GDD §15.2.

## [weak_motor 0..1, strong_motor 0..1, seconds]
const FIRE := [0.15, 0.35, 0.12]
const HIT := [0.35, 0.70, 0.25]
const ALARM := [0.20, 0.40, 0.20]

static func pulse_fire() -> void:
	_pulse(FIRE)

static func pulse_hit() -> void:
	_pulse(HIT)

static func pulse_alarm() -> void:
	_pulse(ALARM)

static func _pulse(spec: Array) -> void:
	if not enabled():
		return
	for dev in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, float(spec[0]), float(spec[1]), float(spec[2]))

## Is controller vibration enabled? (gameplay/vibration; degrades to false without SettingsManager.) Pure-ish.
static func enabled() -> bool:
	var s := Services.settings()
	return s != null and bool(s.get_value("gameplay", "vibration"))
