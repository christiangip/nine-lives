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

## Phases
### Phase 21.1 — Accessibility
- [ ] Implement + verify every accessibility option end-to-end; document in Options.

### Phase 21.2 — Performance
- [ ] Profile dense scenes; enforce AI tick/instance budgets; fix hotspots; record before/after.

### Phase 21.3 — Juice & UX polish
- [ ] Feedback/transition pass; final HUD/readability review; reduce-flashing compliance.

### Phase 21.4 — Export & QA
- [ ] Windows/Linux export presets + smoke-run; full-loop QA matrix; migration verification.
- [ ] Release checklist; version stamp; CHANGELOG; tag `m5`.

## Tests (GUT) / checks
- `test_settings_accessibility.gd` — each accessibility toggle changes the intended runtime value and persists.
- `test_migration_release.gd` — a previous-version save migrates with zero data loss (extends 16).
- Perf harness scene + a documented manual FPS check on the target spec.
- Export smoke test: launch each build to the Main Menu in CI or a manual matrix.

## Definition of Done
- [ ] FR-21-1..7 satisfied; phases checked; tests/checks green.
- [ ] **M5 met:** a stable, accessible, performant, exportable, **playable base game** that takes expansions as data (19/20).
