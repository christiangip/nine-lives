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
- [ ] Import presets (.glb, scale, material remap); palette + master materials; grid snapping doc.
- [ ] A small import script/checklist enforcing manifest rows (tools/scripts).

### Phase 18.2 — Sourcing pass
- [~] Curate CC0 packs (Kenney/Quaternius/etc.) for characters, props, environment, UI, audio-adjacent.
      *Curation catalog authored: `../ASSET_CATALOG.md` — maps every real content id → a specific CC0 source, grouped by domain, with import order.*
- [~] Fill the launch archetype's prop/character needs; log placeholders.
      *Phase-1 environment import landed (`../../phase-1-art.md`): 8 CC0 kits (720 models) under
      `game/assets/models/{environment,props}/`, each with an auto-generated browse gallery in
      `game/scenes/art/gallery_*.tscn`; manifest/credits/ART-TODO updated. Characters/weapons/UI/audio pending.*

### Phase 18.3 — Vertical-slice dressing (M2)
- [ ] Light + material pass on the slice archetype; readability check against Pillar 1.

### Phase 18.4 — Ongoing upkeep
- [ ] Keep manifest/credits/ART-TODO current at every import; periodic placeholder-replacement sweeps.

## Tests / checks
- `tools/scripts/check_assets.sh` (to author) — fail CI if a binary asset lacks a manifest row or LFS tracking.
- Manual: palette consistency review; silhouette-readability review per new archetype.

## Definition of Done
- [ ] FR-18-1..7 satisfied; phases checked; asset check passes in CI.
- [ ] M2 slice looks cohesive; no *missing* art (off-style stand-ins allowed but logged).
