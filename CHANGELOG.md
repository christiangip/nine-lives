# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/); the project follows SemVer from the 1.0.0 base game.

## [Unreleased]
_Nothing yet._

## [1.0.0] — 2026-07-06
The **M5 base game**: a first-person stealth-heist roguelite that is playable end to end (Streak → Catch →
bank Legacy → spend in the Hideout → sharper next Streak), accessible, performant, and built to take
expansions as **data, not code**.

### Added
- **Core loop & systems (tasks 01–20):** 10-autoload architecture over a frozen `EventBus`; data-driven
  content registries; first-person controller (stances, stamina, lean, noise); 5-state stealth detection;
  guard AI (patrol/investigate/search/combat); obstacle catalogue + six minigame frameworks; two-axis
  loot/inventory with Drop Points & Escape; loadout/gear/gadgets; going-loud pursuit + cover combat;
  seeded hybrid-procedural mission generation with solvability validation; Streak/Legacy progression with
  Edges & Perks; manifest-driven Hideout stations; three-currency economy with a balancing harness; full
  Options/HUD/menus; strict 10-slot save system with migration; dynamic audio; art/asset pipeline;
  expansion-pack framework; progression milestones + live/daily/seasonal content.
- **Accessibility suite (task 21, FR-21-1):** colorblind detection-band palettes (protanopia/deuteranopia/
  tritanopia) on top of the existing redundant-symbol compass; real **Reduce Flashing** honoured across
  camera shake, the damage vignette, the escalation pulse and the noise ring; a **camera-shake** toggle;
  **controller vibration**; a light, loud-only **aim-assist**; a **language scaffold** (en/es/fr/de locale
  switch + sample translated Menu/Pause strings, live-updating). Full KB+M and gamepad remap, UI scale, FOV,
  subtitles, and hold/toggle stance options were already present and remain.
- **Performance budget (task 21, FR-21-2):** distance-LOD detection sensing with round-robin stagger and a
  sleep tier for distant guards, plus a mission population cap — the deferred "05.5" AI budget. Design and a
  before/after profiling table live in `docs/PERFORMANCE.md`; the enforceable logic is unit-tested.
- **Juice pass (task 21, FR-21-3):** trauma-based first-person camera shake, a damage vignette, a compass
  escalation pulse, and a loud-only hit-confirmation marker — all reduce-flashing-aware and tuned to never
  harm Pillar-1 legibility. Scene transitions share the `GameManager` fade.
- **Release pipeline (task 21, FR-21-4/6/7):** Windows + Linux/X11 `export_presets.cfg`; a `Version` stamp
  (surfaced on the Main Menu and Pause); `docs/RELEASE_CHECKLIST.md` and `docs/QA_MATRIX.md`; a CI export
  smoke-test step.
- **Polish & Performance Sandbox** (`game/scenes/polish/PolishSandbox.tscn`) demonstrating every task-21
  feature with real imported assets.

### Changed
- Version bumped **0.0.1 → 1.0.0**.
- Detection sensing now throttles by distance (no behaviour change within vision range).

### Removed
- The non-functional **Motion Blur** graphics toggle (no Options setting that does nothing).

## [0.0.1] — pre-release
### Added
- Initial repository scaffold: Godot 4.6 project skeleton, autoload stubs, data-driven content folders, GUT
  test scaffolding; the full design/planning docset under `docs/`; the master task list.
