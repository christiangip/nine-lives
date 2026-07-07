# Release Checklist — Nine Lives

**Task 21 · FR-21-4 / FR-21-7.** The repeatable steps to cut a build. The base game ships at **M5 / v1.0.0**;
content keeps flowing through the expansion + live lists (19/20) afterward.

## 1. Version & metadata
- [ ] Bump `application/config/version` in `project.godot` (currently **1.0.0**). `Version.string()` surfaces
      it on the Main Menu + Pause automatically.
- [ ] (Optional) set `Version.build_metadata` from CI (short commit / date / `rc1`).
- [ ] Update `CHANGELOG.md` — move `[Unreleased]` into a dated `[x.y.z]` section.

## 2. Green gates (must pass)
- [ ] `bash tools/scripts/run_tests.sh` — full headless GUT suite green.
- [ ] `bash tools/scripts/validate_content.sh` — content validator exits 0.
- [ ] `bash tools/scripts/check_assets.sh` — manifest + LFS gate exits 0 (no blank/missing assets).
- [ ] `bash tools/scripts/check_docs.sh` — doc-link lint exits 0.
- [ ] CI (`.github/workflows/ci.yml`) green on the release commit.

## 3. Export builds
Requires the **Godot 4.6 export templates** installed (Editor → Manage Export Templates) and a machine with a
display for the smoke-run. Presets are defined in `export_presets.cfg` (Windows Desktop + Linux/X11, embedded
PCK so LFS assets ship inside the binary).

- [ ] Windows: `godot --headless --export-release "Windows Desktop" build/windows/NineLives.exe`
- [ ] Linux: `godot --headless --export-release "Linux/X11" build/linux/NineLives.x86_64`
- [ ] Verify each binary exists and its size looks sane (PCK embedded → tens of MB, not KB).

## 4. Smoke run (per target)
- [ ] Launch the build; it reaches the **Main Menu** showing `Nine Lives v1.0.0`.
- [ ] Assets resolve — models/fonts render (nothing pink/blank), audio plays.
- [ ] New Game → Hideout → a mission → return; no missing-resource errors in the log.
- [ ] Options apply + persist across a relaunch (`user://settings.cfg`).

## 5. Full-loop QA
- [ ] Work through `docs/QA_MATRIX.md` (New Game → Streak → Catch → spend → Continue → migrate, across slots).
- [ ] `docs/PERFORMANCE.md` — record the 60-FPS-on-target-spec measurement in a dense scene.

## 6. Tag & publish
- [ ] Commit the version bump + CHANGELOG.
- [ ] Tag the release: `git tag -a v1.0.0 -m "Nine Lives 1.0.0 (M5 base game)"` and the milestone tag `m5`.
- [ ] Attach the Windows + Linux builds to the release.

## Notes
- **Export templates are environment-specific** — they are not vendored in the repo; install them once per
  machine. The CI export step is best-effort and skips cleanly if templates are absent.
- Do **not** commit `build/` output or `export.cfg` (both gitignored). `export_presets.cfg` **is** committed
  (portable, no secrets).
