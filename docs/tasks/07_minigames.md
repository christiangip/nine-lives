# 07 — Minigames

**Milestone:** M0 (lockpick + hack) · M2 (full set) · **Depends on:** 02, 06 · **Blocks:** —
**Implements:** GDD §9.8 · **Decisions:** scaled by attribute/gear; FP diegetic close-ups.

> **↩ From 06 (Obstacles):** the obstacles are built and call the `Minigame` contract
> (`solved`/`failed`/`aborted`) but ship **no overlay** — each resolves its alternates first and
> treats the skill outcome as an input to a tested consequence seam. Build the overlays and feed
> results back: `Lock.resolve_attempt(success)` (lockpick; snaps a `PickPouch` pick on fail),
> `Safe`/`DisplayCase` (emit `minigame_requested` → dial / e-lock hack), the `HackTarget` timed
> proximity hack (e-lock/keypad Mastermind/camera loop-vs-disable), and `BreachPoint` (drill
> gauge + repair, FR-07-8). Come back and tick these + the relevant boxes in `06_…md`.

## Overview
A small set of standardized, reusable minigame frameworks subclassing `Minigame`.
Each scales by the relevant attribute + gear, snaps to a focused diegetic overlay,
and is skippable via clues/intel where sensible. Never the *only* solution.

## Functional Requirements
- **FR-07-1** All minigames extend `Minigame` and emit `solved` / `failed(reason)` / `aborted`.
- **FR-07-2** Difficulty parameterizes each (tiers from the obstacle/contract); attribute + gear widen tolerances/speed.
- **FR-07-3** **Lockpick:** rotate to a sweet-spot arc; tension opens the pin; missing risks a snap; Lockpicking widens arc + reduces snaps.
- **FR-07-4** **Safe-crack:** chain dial clicks at correct numbers (audio+subtle visual cue); more wheels/tighter tolerance at tiers; stethoscope widens cues.
- **FR-07-5** **Hack:** node-routing/sequence under a soft timer with proximity-lock; Hacking adds fault tolerance; distinct visual variants per target type.
- **FR-07-6** **Keypad:** Mastermind-style deduction; Pickpocketing/Hacking unrelated; supports found-code instant solve.
- **FR-07-7** **Pickpocket:** moving timing meter; stop in the safe zone; window scales with Pickpocketing; failure nudges NPC suspicious.
- **FR-07-8** **Drill/Thermite:** not a puzzle — a tension manager: progress timer, jam events needing a repair interaction, continuous noise emission.
- **FR-07-9** Each minigame is keyboard+gamepad playable and accessibility-aware (no reliance on color/audio alone).

## Phases
### Phase 07.1 — Framework (M0)
- [x] `Minigame` lifecycle, overlay mount/unmount, pause-world handling, abort path.
- [x] Attribute+gear injection API; difficulty mapping helper.

### Phase 07.2 — Lockpick + Hack (M0)
- [x] Lockpick arc/tension/snap; juice + SFX hooks (17). *(SFX/juice = `TODO[17]` hooks; snap delegates to `Lock.snap_chance`.)*
- [x] Hack node-routing + soft timer + proximity-lock; one visual variant.

### Phase 07.3 — Safe + Keypad (M2)
- [x] Safe dial clicks + wheels + stethoscope; combo-clue instant-solve path.
- [x] Keypad deduction + found-code path.

### Phase 07.4 — Pickpocket + Drill/Thermite (M2)
- [~] Pickpocket timing meter + suspicion-on-fail. *(Framework + seams + tests + greybox done; the fail
  emits `failed("caught")` as the hook — the NPC suspicion reaction wires with the civilian roster,
  `↩ From 07` in `05`/`11`.)*
- [x] Drill/thermite tension manager + jam/repair + noise. *(Overlay drives `BreachPoint`; timer/jam/noise live there.)*

## Tests (GUT)
- [x] `test_minigame_lifecycle.gd` — begin→solve/fail/abort emit correct signals once.
- [x] `test_lockpick_scaling.gd` — higher Lockpicking widens the sweet-spot and lowers snap probability.
- [x] `test_hack_timer_proximity.gd` — running out of soft time fails; leaving proximity pauses.
- [x] `test_keypad_deduction.gd` — correct deduction sequence solves; found-code path instant-solves.
- [x] `test_pickpocket_window.gd` — Pickpocketing widens the safe-zone window.
- [x] `test_safecrack_scaling.gd`, `test_minigame_host_routing.gd`, `test_minigame_registry.gd` — +3 for parity.

## Definition of Done
- [x] M0: lockpick + hack fully playable and attribute-scaled; tests green. *(Godot 4.6.3, GUT 148/148.)*
- [~] M2: all six frameworks shipped, accessible, and wired to obstacles (06). *(All six frameworks +
  host wiring code-complete & green; residual: the F6 `MinigameGreybox.tscn` "feel" sign-off, and the
  pickpocket→NPC attach point which is blocked on the civilian roster — `↩ From 07` in `05`/`11`.)*

## Progress note
**Code + automated DoD complete & verified green** on Godot 4.6.3 (headless GUT **148/148**, +36 task-07
tests). A `Minigame` (Control) base + six subclasses in `game/systems/minigames/` (Lockpick, Hack,
SafeCrack, Keypad, Pickpocket, Drill), each with **pure static seams** (unit-tested) under thin
code-built overlay glue; keyboard **and** gamepad via built-in `ui_*` actions (FR-07-9). Tunables live in
a new **`MinigameConfigDef`** (+ `default_minigame.tres`), registered as the **15th `Content` registry**
`Content.minigames`; added the missing **`pickpocketing`** `AttributeDef`. A **`MinigameHost`** driver
maps `kind → overlay`, injects difficulty/attribute/gear (attribute `TODO[12]`, gear `TODO[09]`), and
routes `solved/failed/aborted` back through one polymorphic **`Obstacle.apply_minigame_result(kind,
success)`**. **EventBus stayed frozen** — the obstacle→host request is a local `minigame_requested`
signal lifted to the `Obstacle` base. Closes the `↩ From 06` overlay slices (lockpick / safe dial /
e-lock hack / keypad Mastermind / drill gauge); the six task-06 obstacle consequence seams + their tests
stayed untouched. **Residual (`[~]`):** F6 sign-off on `game/scenes/minigames/MinigameGreybox.tscn`,
mirroring 03/04.
