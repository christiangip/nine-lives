# 21 — Release, Polish, Accessibility & Performance

**Milestone:** M4–M5 · **Depends on:** all · **Blocks:** M5 release
**Implements:** GDD §15.2 (accessibility), §3 (perf), §20 (risks) · **Decisions:** all.

## Overview
The final gate to a shippable **base game**: accessibility suite, performance budget,
"juice," export pipeline, and a QA pass that exercises the whole loop across saves
and updates.

## Functional Requirements
- **FR-21-1** Accessibility: colorblind modes, UI scale, full remap (KB+M + gamepad), subtitles/captions, reduce-flashing, hold/toggle options, aim assist (loud), language scaffold.
- **FR-21-2** Performance: hold **60 FPS on mid-range hardware** in a dense populated scene; AI/instance budgets enforced; profiling captures committed to `docs/`.
- **FR-21-3** Juice pass: camera/hit/UI feedback, transitions, screen-state readability — without harming Pillar-1 legibility.
- **FR-21-4** Export presets for Windows & Linux produce runnable builds; LFS assets resolve in the build.
- **FR-21-5** Full-loop QA: tutorial → Streak → Catch → spend → Continue → update/migrate, across all 10 slots, with no data loss.
- **FR-21-6** Complete `CREDITS.md` / `ASSET_MANIFEST.csv`; no blank/missing assets; ART-TODO triaged.
- **FR-21-7** Build/version stamping + a release checklist; CHANGELOG updated.

> **Progress (2026-07-06 · code + automated DoD complete & verified green on Godot 4.6.3 — headless GUT
> 436/436, validators green).** Built additively over the frozen EventBus + 10-autoload spine (new logic is
> pure-static helpers / a `RefCounted`, no 11th singleton).
> **21.1 Accessibility:** colorblind detection-band palettes (`UITheme.detection_color_for` + `CompassEye`
> reads `gameplay/colorblind`); real Reduce Flashing across the noise ring, camera shake, damage vignette and
> escalation pulse; a `video/camera_shake` toggle driving a new trauma-based `CameraShake` on the FP camera;
> controller vibration via a new `Haptics` gate; a light loud-only aim-assist (`PlayerCombat.assist_aim`);
> and a language scaffold (`Localization` — code-registered en/es/fr/de + `strings.csv`; `SettingsManager
> ._apply_gameplay` sets the locale; Menu/Pause use `tr()` keys that flip live). Removed the dead Motion Blur
> toggle. **21.2 Performance (the deferred 05.5):** distance-LOD detection sensing + round-robin stagger +
> sleep tier (`DetectionSensor.sense_interval_for_distance`/`should_sense`, tunables on `DetectionConfigDef`)
> and a mission population cap (`AIConfigDef.max_active_guards`); design + method in `docs/PERFORMANCE.md`.
> **21.3 Juice:** camera shake, HUD damage vignette, compass escalation pulse, loud-only hit marker — all
> reduce-flashing-aware; scene swaps already share the `GameManager` fade. **21.4 Export/QA:**
> `export_presets.cfg` (Windows + Linux), a `Version` stamp on Main Menu + Pause (project bumped 0.0.1→1.0.0),
> `test_migration_release.gd`, `CHANGELOG`/`RELEASE_CHECKLIST`/`QA_MATRIX`, CREDITS/ART-TODO triage, a CI
> export smoke step. Demo: `game/scenes/polish/PolishSandbox.tscn`. **Residual (`[~]`):** the manual passes a
> headless run can't do — the F6 sandbox "feel", the 60-FPS-on-target-spec measurement (`docs/PERFORMANCE.md`
> table), and the real Windows/Linux export + smoke-run (`docs/RELEASE_CHECKLIST.md`). **M5** additionally
> gates on task 22 (tutorial, per FR-21-5) and the residual F6 sign-offs on 04–09 / 20.

## Phases
### Phase 21.1 — Accessibility
- [x] Implement + verify every accessibility option end-to-end; document in Options. *(Code + automated tests
  green; manual F6 "feel" sign-off on `PolishSandbox.tscn` pending.)*

### Phase 21.2 — Performance
- [~] Profile dense scenes; enforce AI tick/instance budgets; fix hotspots; record before/after. *(Budgets
  enforced + unit-tested + `docs/PERFORMANCE.md` written; the before/after FPS numbers are the manual
  target-spec pass.)*

### Phase 21.3 — Juice & UX polish
- [x] Feedback/transition pass; final HUD/readability review; reduce-flashing compliance.

### Phase 21.4 — Export & QA
- [~] Windows/Linux export presets + smoke-run; full-loop QA matrix; migration verification. *(Presets +
  `QA_MATRIX.md` + `test_migration_release.gd` done; the export smoke-run is manual per `RELEASE_CHECKLIST.md`.)*
- [~] Release checklist; version stamp; CHANGELOG; tag `m5`. *(Checklist + version stamp + CHANGELOG done;
  tagging `m5` is the final manual release step.)*

## Tests (GUT) / checks
- `test_settings_accessibility.gd` — each accessibility toggle changes the intended runtime value and persists.
- `test_migration_release.gd` — a previous-version save migrates with zero data loss (extends 16).
- Perf harness scene + a documented manual FPS check on the target spec.
- Export smoke test: launch each build to the Main Menu in CI or a manual matrix.

## Definition of Done
- [~] FR-21-1..7 satisfied; phases checked; tests/checks green. *(Code + automated checks green — GUT
  436/436, content/asset/doc validators exit 0. Remaining: the manual F6 sandbox feel, the target-spec FPS
  measurement, and the real export smoke-run.)*
- [ ] **M5 met:** a stable, accessible, performant, exportable, **playable base game** that takes expansions
  as data (19/20). *(Also gated on task 22 (tutorial) and the residual manual F6 sign-offs on 04–09 / 20.)*
