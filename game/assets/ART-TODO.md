# ART-TODO Registry

The "never leave a gap" rule (GDD §13.4): if no on-style asset exists for a need,
drop in ANY CC0 placeholder so nothing is ever missing — and log it here for
later replacement.

**Scale-review harness:** open `game/scenes/art/gallery_hub.tscn` (F6) to browse every
kit gallery; each shows a 1.8 m human capsule beside its rows. Flag any kit that reads
off-scale here for a per-file import-scale pass (`AssetGallery.gd` / phase-1-art.md).

| Placeholder asset | Stands in for | Style mismatch | Priority | Replace with |
|---|---|---|---|---|
| `scifi_megakit` (Quaternius) | high-security / server-room / vault dressing | Sci-fi look vs. grounded-crime pillar | Med | On-style grounded vault door + security fixtures |
| _gap:_ dedicated **vault door** | `bank_vault` (3×3 setpiece) | using SciFi/modular door as stand-in | High | CC0 grounded vault door (Poly Pizza "vault door") |
| _gap:_ **museum pedestals / frames** | Museum archetype dressing | using bookcases/columns | Low | CC0 pedestal + framed-art props |
| _gap:_ **warehouse forklift / shelving** | Warehouse archetype dressing | factory/survival crates only | Low | CC0 forklift + pallet racking |
| `Prop_AccessPoint` (scifi) | `security_camera` prefab | sci-fi wall unit, not a real PTZ camera | Med | Poly Pizza "security camera" (CC0) |
| _gap:_ **pallet** | `bank_loading_dock` prefab set | no CC0 pallet model imported | Low | Kenney Warehouse / Poly Pizza "pallet" |
| **Safe** (CreativeTrio), **Gold Bars** (hat_my_guy) | `safe_basic`, `gold_bar` loot | author credited but **license marker not provided** | Low | confirm CC0/CC-BY on Poly Pizza (credited either way; add license to manifest) |
| _gap:_ **laser_grid, motion_sensor, pressure_plate, silent_alarm, stolen_data** | task-06 obstacles / task-08 loot | not found in the phase-3 download | Med | source CC0 (Poly Pizza / Kenney) later |
| _gap:_ **wall/floor tiling materials** | marble/carpet/tile surfaces | models pre-textured only | Low | ambientCG / Poly Haven PBR sets (recolor to palette) |
| **procedural music beds** (`AudioManager._make_bed`) | Calm/Tense/Combat/Resolve music layers (task 17) | in-code tonal placeholders, not composed music | Med | real layered stems (grounded/heist tone, Q3) — swap into `AudioConfigDef` |
| Kenney interface/impact SFX | spotted-sting / alarm klaxon / running drill (task 17) | approximated from CC0 UI/impact set, not bespoke | Low | dedicated diegetic SFX (klaxon, drill loop, pick-snap) — remap `AudioConfigDef.sfx_paths` |
| _wiring (task 18):_ **section shells** — only `vault` + `entry_lobby` authored (`game/prefabs/sections/`) | the other Bank sections (teller_hall/office/server_room/loading_dock) + Museum/Warehouse archetypes | they fall back to a master-materialed procedural tile (still solvable + legible, just less dressed) | Med | author a `SectionShell`-based prefab per section + set `SectionDef.scene` |
| _wiring (task 18):_ **loot models** via `LootDef.mesh` (cash/gold/painting/diamond raw `.glb`) | in-mission loot pickups | shown at import scale over an invisible collider — may read off-scale until checked in-context | Low | per-file import-scale pass (gallery harness) or wrap each in a `PropPrefab` |
| _wiring (task 18):_ **`Swat.gltf`** actor model | guard / responder / SWAT / specialist roster (`EnemyDef.model`) | one CC0 model stands in for every hostile tier (Inspector=`Suit`, civilian=`Casual`) | Med | recolored/variant models per tier — the tinted feet-ring carries the blue/gold/cyan role read meanwhile |
