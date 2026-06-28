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
