extends Minigame
class_name KeypadMinigame
## Keypad overlay (FR-07-6, GDD §9.2/§9.8): a faster Mastermind-style deduction — guess the code,
## read exact/partial feedback, deduce it before the attempts run out. Longer codes at higher tiers.
## A FOUND CODE skips it entirely (handled by the HackTarget obstacle's clue path). Focused close-up →
## pauses the world. The deduction maths are pure seams; the entry glue is thin. See docs/tasks/07_minigames.md.

var _secret: Array[int] = []
var _length: int = 3
var _symbols: int = 6
var _guess: Array[int] = []
var _cursor: int = 0
var _guesses_left: int = 8
var _last_feedback: Array = [0, 0]
var _readout: Label

# --- Pure seams (deterministic; unit-tested headless) ----------------------
## Mastermind feedback for a guess vs the secret: [exact, partial]. `exact` = right symbol AND
## position; `partial` = right symbol, wrong position (counted among the non-exact positions only,
## honouring duplicates). Pure.
static func evaluate_guess(guess: Array, secret: Array) -> Array:
	var exact := 0
	var g_counts: Dictionary = {}
	var s_counts: Dictionary = {}
	var n := mini(guess.size(), secret.size())
	for i in n:
		if guess[i] == secret[i]:
			exact += 1
		else:
			g_counts[guess[i]] = int(g_counts.get(guess[i], 0)) + 1
			s_counts[secret[i]] = int(s_counts.get(secret[i], 0)) + 1
	var partial := 0
	for sym in g_counts:
		partial += mini(int(g_counts[sym]), int(s_counts.get(sym, 0)))
	return [exact, partial]

## Is this feedback a full solve? exact == the code length. Pure.
static func is_solved(feedback: Array, length: int) -> bool:
	return feedback.size() > 0 and int(feedback[0]) == length

## Code length for a tier. Pure.
static func code_length_for_tier(base: int, tier: int, per_tier: int) -> int:
	return maxi(1, base + maxi(0, tier - 1) * per_tier)

# --- Lifecycle -------------------------------------------------------------
func begin(ctx: Dictionary = {}) -> void:
	super.begin(ctx)
	_symbols = maxi(2, config.keypad_symbol_count)
	_length = code_length_for_tier(config.keypad_length_base, difficulty, config.keypad_length_per_tier)
	_guesses_left = maxi(1, config.keypad_max_guesses)
	_secret.clear()
	_guess.clear()
	for _i in _length:
		_secret.append(randi() % _symbols)
		_guess.append(0)
	_cursor = 0
	_last_feedback = [0, 0]
	_build_ui()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # offsets too: anchors alone keep the 0x0 rect a code-built Control starts with
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.05, 0.07, 0.85)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_readout = Label.new()
	_readout.set_anchors_preset(Control.PRESET_CENTER)
	_readout.grow_horizontal = Control.GROW_DIRECTION_BOTH   # else the label's top-left sits at centre
	_readout.grow_vertical = Control.GROW_DIRECTION_BOTH
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_readout)
	_refresh()

func _process(_delta: float) -> void:
	if _finished:
		return
	if Input.is_action_just_pressed(&"ui_left"):
		_cursor = (_cursor - 1 + _length) % _length
		_refresh()
	elif Input.is_action_just_pressed(&"ui_right"):
		_cursor = (_cursor + 1) % _length
		_refresh()
	elif Input.is_action_just_pressed(&"ui_up"):
		_guess[_cursor] = (_guess[_cursor] + 1) % _symbols
		_refresh()
	elif Input.is_action_just_pressed(&"ui_down"):
		_guess[_cursor] = (_guess[_cursor] - 1 + _symbols) % _symbols
		_refresh()
	elif Input.is_action_just_pressed(&"ui_accept"):
		_submit()

func _submit() -> void:
	_last_feedback = evaluate_guess(_guess, _secret)
	if is_solved(_last_feedback, _length):
		_finish_solved()
		return
	_guesses_left -= 1
	if _guesses_left <= 0:
		_finish_failed("locked_out")
	else:
		_refresh()

func _refresh() -> void:
	if _readout == null:
		return
	var row := ""
	for i in _length:
		row += ("[%d]" if i == _cursor else " %d ") % _guess[i]
	_readout.text = "KEYPAD  ◄ ► pick digit, ▲▼ change, [Enter] submit   Esc: cancel\n%s\nlast: %d exact, %d partial   tries left: %d" % [
		row, int(_last_feedback[0]), int(_last_feedback[1]), _guesses_left]
