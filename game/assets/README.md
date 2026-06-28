# Assets

Mixed-source, CC0-first art/audio. **Standards (GDD §13):**
- Format: **glTF (.glb)** for all models.
- Scale: **1 unit = 1 m**; modular pieces snap to a shared grid.
- A locked palette + master material set so mixed sources read as one world.
- Large binaries are tracked with **Git LFS** (see `/.gitattributes`).

Tracking files (keep current at import time):
- `ASSET_MANIFEST.csv` — every asset → source → license → author → where used.
- `CREDITS.md` — attribution for CC-BY/OFL assets (ships with the game).
- `ART-TODO.md` — placeholder/off-style assets awaiting replacement.

Sources: Kenney, Quaternius, Poly Pizza, OpenGameArt (CC0 filter), Poly Haven,
ambientCG, Freesound, Incompetech/FMA, Google Fonts. See docs/ASSET_PIPELINE.md.
