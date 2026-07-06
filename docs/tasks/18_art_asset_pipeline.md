# 18 — Art & Asset Pipeline

**Milestone:** M2 (first pass) · ongoing · **Depends on:** parallel · **Blocks:** —
**Implements:** GDD §13 · **Decisions:** stylized low-poly, CC0-first; see `../ASSET_PIPELINE.md`.

## Overview
Make mixed-source CC0 assets read as one cohesive, readable world — and keep them
license-clean. This list operationalizes `ASSET_PIPELINE.md`: a sourcing pass,
import standards, master materials, and the manifest/credits/ART-TODO discipline.

## Functional Requirements
- **FR-18-1** All models import as glTF `.glb` at 1u=1m and snap to the modular grid (consumed by 11).
- **FR-18-2** A master material set + locked palette; imported assets are recolored/retextured to fit.
- **FR-18-3** Every imported asset has a row in `ASSET_MANIFEST.csv`; CC-BY/OFL assets are in `CREDITS.md`.
- **FR-18-4** "Never leave a gap": any missing-need uses a CC0 placeholder logged in `ART-TODO.md`.
- **FR-18-5** A consistent character rig/animation set shared across sourced characters.
- **FR-18-6** Binaries tracked via Git LFS; no loose large binaries committed un-tracked.
- **FR-18-7** A first art pass dresses the M2 vertical-slice archetype to shippable quality.

## Phases
### Phase 18.1 — Standards & tooling
- [x] Import presets (.glb, scale, material remap); palette + master materials; grid snapping doc.
      *Master `StandardMaterial3D` set in `game/assets/materials/` + a `Palette` accessor
      (`game/systems/art/Palette.gd`); standards documented in `../ASSET_PIPELINE.md` (glTF 1u=1m, per-kit
      `.import` root_scale, `CELL = 6 m` section grid, palette remap).*
- [x] A small import script/checklist enforcing manifest rows (tools/scripts).
      *`tools/scripts/check_assets.sh` — every binary under `game/assets/` needs a manifest row + LFS
      tracking; no stale rows. Wired into CI after the GUT + doc-lint steps.*

### Phase 18.2 — Sourcing pass
- [~] Curate CC0 packs (Kenney/Quaternius/etc.) for characters, props, environment, UI, audio-adjacent.
      *Curation catalog authored: `../ASSET_CATALOG.md` — maps every real content id → a specific CC0 source, grouped by domain, with import order.*
- [x] Fill the launch archetype's prop/character needs; log placeholders.
      *Phase-1 environment import landed (`../../phase-1-art.md`): 8 CC0 kits (720 models) under
      `game/assets/models/{environment,props}/`, each with an auto-generated browse gallery in
      `game/scenes/art/gallery_*.tscn`. Wired into gameplay this pass via the `scene`/`mesh`/`model` def
      seams (real Bank section shells + prop prefabs + loot + character models); remaining prop/scale gaps
      logged in `ART-TODO.md`. Characters share the Quaternius Modular Men rig (FR-18-5).*

### Phase 18.3 — Vertical-slice dressing (M2)
- [x] Light + material pass on the slice archetype; readability check against Pillar 1.
      *Master materials on the floor/section tiles/showcase shell, a WorldEnvironment + key/fill lighting on
      the generated mission (skipped when a scene ships its own), and actors get real models with a tinted
      feet-ring so blue-guard / gold-keycarrier / cyan-civilian threats stay legible in shadow. **F6
      readability/cohesion sign-off passed 2026-07-05.***

### Phase 18.4 — Ongoing upkeep
- [x] Keep manifest/credits/ART-TODO current at every import; periodic placeholder-replacement sweeps.
      *Current as of this pass; `check_assets.sh` now guards manifest/LFS discipline in CI so drift fails the
      build. (Upkeep continues per import — the replacement sweeps for the logged stand-ins are tracked in
      `ART-TODO.md`.)*

## Tests / checks
- `tools/scripts/check_assets.sh` — **authored + CI-wired**; fails on a missing manifest row, a non-LFS
  binary, or a stale row (proven non-rubber-stamp: it flagged a real texture gap on first run).
- `game/tests/unit/test_palette_materials.gd` + `game/tests/integration/test_art_scenes.gd` — the master
  material set resolves, the `scene`/`mesh`/`model` def seams exist + are populated, and the dressed
  generated mission builds with real `SectionShell` nodes in-tree (headless).
- Manual: palette consistency review; silhouette-readability review per archetype — **signed off 2026-07-05.**

## Definition of Done
- [x] FR-18-1..7 satisfied; phases checked; asset check passes in CI.
      *FR-18-1 (glTF 1u=1m + `CELL` grid snap), FR-18-2 (master materials + locked palette via `Palette`),
      FR-18-3 (manifest rows + `check_assets.sh`), FR-18-4 (gaps logged in ART-TODO), FR-18-5 (shared
      Quaternius Modular Men rig/anim across actors), FR-18-6 (LFS, CI-gated), FR-18-7 (M2 Bank slice dressed
      in both the generated mission and the standalone showcase). F6 cohesion sign-off passed 2026-07-05.*
- [x] M2 slice looks cohesive; no *missing* art (off-style stand-ins allowed but logged in `ART-TODO.md`).
