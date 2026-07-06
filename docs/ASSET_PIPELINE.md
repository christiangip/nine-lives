# Asset Pipeline & License Hygiene

Implements GDD §13. The rule: **mixed-source assets must read as one world, and
every asset must be license-clean for distribution.**

## Style target
Stylized low-poly, controlled palette, strong silhouettes, lightweight materials
(flat/toon or simple PBR). Chosen because abundant CC0 assets exist in this style,
it stays consistent across procedural levels, it's performant, and silhouettes +
color carry the readability the stealth design needs.

## Standards (non-negotiable)
- **Format:** glTF **`.glb`** for all models (Godot 4 native import).
- **Scale:** 1 Godot unit = 1 meter. Modular pieces snap to a shared grid so the
  assembler can socket them cleanly (see `11_mission_generation.md`).
- **Master materials + locked palette:** retexture/recolor imported assets to the
  palette so sources blend. Keep the palette + master material set in
  `game/assets/materials/`.
- **Rigs:** standardize one humanoid rig/animation set so different-sourced
  characters share animations.

## Sourcing (CC0-first)
Prefer **CC0** to minimize obligations; use CC-BY only when needed.
Kenney.nl · Quaternius · Poly Pizza · OpenGameArt (CC0 filter) · Poly Haven /
ambientCG (textures/HDRIs) · Freesound (CC0/CC-BY) + Kenney audio (SFX) ·
Free Music Archive / Incompetech (music) · Google Fonts (UI).

> Fetching/curating specific packs is its own task (`18_art_asset_pipeline.md`),
> kept separate from systems work. Until then, placeholders fill every gap.

## The "never leave a gap" rule
If no on-style asset exists for a need, drop in **any** CC0 placeholder so nothing
is ever missing — then log it in `game/assets/ART-TODO.md` for later replacement.
Nothing ships blank.

## License hygiene (shippability)
- **`game/assets/ASSET_MANIFEST.csv`** — one row per asset: path, type, source,
  URL, license, author, where-used, placeholder?, notes. No asset enters the repo
  without a row.
- **`game/assets/CREDITS.md`** — attribution for every CC-BY / OFL asset; ships
  with the game.
- Binaries are tracked with **Git LFS** (`.gitattributes`). Run `git lfs install`
  after cloning before adding any binary asset.

## Import checklist (per asset)
1. Confirm license allows redistribution; record it.
2. Convert/export to `.glb`; set scale to meters.
3. Reassign to a master material / recolor to palette.
4. Add a row to `ASSET_MANIFEST.csv` (+ `CREDITS.md` if CC-BY).
5. If off-style or placeholder, add a row to `ART-TODO.md`.

## Realized in the engine (task 18)
- **Master materials + palette.** The locked palette + master `StandardMaterial3D` set live in
  `game/assets/materials/*.tres`, read through one accessor `Palette` (`game/systems/art/Palette.gd`):
  `Palette.material(&"floor"/&"wall"/&"metal"/…)` and `Palette.tinted(color)`. The mission realizer, the
  section/prop prefabs and the Bank showcase all recolor through it, so a palette change is one edit; a
  missing `.tres` falls back to a flat palette colour (never hard-fails — the `UITheme` philosophy).
- **Grid + scale.** 1u = 1m; the mission grid is `CELL = 6 m` (`MissionLayout.CELL_SIZE`). Per-asset scale
  is baked into each `*.import` (`nodes/root_scale`; Kenney env ≈×6, characters ×1). Section shells
  (`game/prefabs/sections/`, `SectionShell`) size themselves `footprint × CELL` and leave a doorway on
  every edge, so they snap into the assembler regardless of which socket orientation it picks.
- **The art `scene` seams (data, not code).** Real geometry attaches to gameplay purely through def fields,
  realized by `MissionController` with a greybox fallback when unset: `SectionDef.scene` (section shell),
  `ObstacleDef.scene` (prop prefab), `LootDef.mesh` (loot model), `EnemyDef.model` (character). Actors keep
  the detection-cone wedge + a tinted feet-ring so threats stay legible after the model swap.
- **CI gate.** `tools/scripts/check_assets.sh` fails the build if any binary under `game/assets/` lacks a
  manifest row or LFS tracking, or if a manifest row is stale. Runs in `.github/workflows/ci.yml` after the
  GUT + doc-lint steps.
