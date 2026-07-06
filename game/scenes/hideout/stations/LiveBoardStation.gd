extends StationPanel
## The Wire — the live-content board (task 20). One diegetic panel for: the milestone arcs (auto-unlocks
## over many runs, FR-20-1), the week's rotating event modifier (FR-20-3), the Daily & Weekly Challenges
## (date-seeded, launched standalone via GameManager.enter_challenge, FR-20-2), and the active season's
## goals (claim Legacy + a dormant title, FR-20-4). Thin-wraps already-tested LiveOps / ProgressionManager
## seams; EventBus stays FROZEN. Appears in the Hideout automatically (manifest-driven, live_board.tres).
## See docs/tasks/20_progression_milestones.md.

func _station_title() -> String:
	return "The Wire"

func _populate(_body_container: VBoxContainer) -> void:
	var cfg := LiveOps.config()
	_populate_event(cfg)
	_populate_challenges(cfg)
	_populate_season(cfg)
	_populate_milestones()

# --- The week's event modifier (FR-20-3) -----------------------------------
func _populate_event(cfg: Dictionary) -> void:
	_heading("This Week")
	var active := LiveOps.active_modifiers(cfg)
	if active.is_empty():
		_note("A calm week — no global event modifier on the board right now.")
	else:
		var names: Array = []
		for mid in active:
			names.append(_modifier_name(mid))
		_note("Event: %s — applied board-wide until the rotation turns." % ", ".join(names))

# --- Daily & Weekly Challenges (FR-20-2) -----------------------------------
func _populate_challenges(cfg: Dictionary) -> void:
	_heading("Challenges")
	_note("Seeded from the date — the same job for everyone. Played standalone; your endless Streak is never at risk.")
	_challenge_row(cfg, "daily", LiveOps.daily_seed(), int(cfg.get("daily_legacy_reward", 0)))
	_challenge_row(cfg, "weekly", LiveOps.weekly_seed(), int(cfg.get("weekly_legacy_reward", 0)))

func _challenge_row(cfg: Dictionary, kind: String, seed: int, reward: int) -> void:
	var candidates := LiveOps.challenge_candidates(cfg, kind)
	var contract := LiveOps.challenge_contract(seed, candidates, kind, int(cfg.get("challenge_tier", 3)))
	if contract.archetype_id == &"":
		_note("%s Challenge: unavailable (no eligible location)." % kind.capitalize())
		return
	var best := LiveChallenges.best_for(seed)
	var label := "%s — %s" % [kind.capitalize(), _contract_headline(contract)]
	if best.has("best_seconds"):
		label += "   ·   best %s" % _fmt_time(float(best.get("best_seconds", 0.0)))
	elif int(best.get("plays", 0)) > 0:
		label += "   ·   not yet cleared"
	var btn := _action_row(label, "Launch %s" % kind.capitalize(), true)
	btn.pressed.connect(_on_launch_challenge.bind(contract, kind, reward))

func _on_launch_challenge(contract: Contract, kind: String, reward: int) -> void:
	GameManager.enter_challenge(contract, kind, reward)

# --- Season goals (FR-20-4) ------------------------------------------------
func _populate_season(cfg: Dictionary) -> void:
	var season := LiveOps.active_season(cfg)
	if season.is_empty():
		return
	_heading("Season: %s" % String(season.get("title", "Season")))
	if ProgressionManager != null:
		ProgressionManager.ensure_season(season)   # snapshot the baseline on first view
	var sid := String(season.get("id", ""))
	for g in season.get("goals", []):
		if not (g is Dictionary):
			continue
		var target := int(g.get("target", 1))
		var prog := ProgressionManager.season_goal_progress(season, g) if ProgressionManager != null else 0
		var claimed := ProgressionManager.is_season_goal_claimed(sid, String(g.get("id", ""))) if ProgressionManager != null else false
		var complete := ProgressionManager.season_goal_complete(target, prog) if ProgressionManager != null else false
		var label := "%s   (%d / %d)" % [String(g.get("display", "Goal")), mini(prog, target), target]
		if claimed:
			label += "   ✓ claimed"
		var btn := _action_row(label, "Claim +%d" % int(g.get("reward_legacy", 0)), complete and not claimed)
		if complete and not claimed:
			btn.pressed.connect(_on_claim.bind(season, g))

func _on_claim(season: Dictionary, goal: Dictionary) -> void:
	if ProgressionManager != null and ProgressionManager.claim_season_reward(season, goal):
		refresh()
		if SaveManager != null:
			SaveManager.autosave()

# --- Milestone arcs (FR-20-1) ----------------------------------------------
func _populate_milestones() -> void:
	_heading("Milestone Arcs")
	if Content == null or Content.milestones == null or ProgressionManager == null:
		return
	var earned := int(ProgressionManager.stats.get(&"legacy_earned", 0))
	_note("Lifetime Legacy earned: %d — arcs unlock content for free as it grows." % earned)
	var ms := Content.milestones.all()
	ms.sort_custom(func(a, b) -> bool: return int(a.order) < int(b.order))
	for res in ms:
		var m := res as MilestoneDef
		if m == null:
			continue
		var reached := m.id in ProgressionManager.milestones_reached
		var status := "✓ Unlocked" if reached else _milestone_requirement(m)
		_note("%s — %s\n    %s" % [m.display_name, m.description, status])

func _milestone_requirement(m: MilestoneDef) -> String:
	var parts: Array = []
	if m.threshold_legacy > 0:
		parts.append("%d lifetime Legacy" % m.threshold_legacy)
	if m.require_special_loot != &"":
		parts.append("deliver a special trophy")
	return "Locked — needs %s" % (" + ".join(parts) if not parts.is_empty() else "…")

static func _fmt_time(secs: float) -> String:
	var s := int(round(maxf(0.0, secs)))
	@warning_ignore("integer_division")
	return "%d:%02d" % [s / 60, s % 60]
