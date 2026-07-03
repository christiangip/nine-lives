# Asset Catalog — Curated CC0 Sourcing Plan

Curation pass for **task 18.2**. Every row maps a **real content ID already in the
repo** to a specific copyright-free source, grouped by domain. All picks are **CC0
unless flagged CC-BY/OFL** (those need a `CREDITS.md` entry). Style target:
stylized low-poly, locked palette, `.glb`, 1u = 1m (`docs/ASSET_PIPELINE.md`).

**How to use:** work top-down per group; on import, add a row to
`game/assets/ASSET_MANIFEST.csv`, recolor to palette, and log any off-style
stand-in in `ART-TODO.md`. IDs below match the `.tres` content the game already
spawns, so a mesh dropped in "just appears" over its greybox primitive.

**Primary sources (all free, redistribution-OK):**
Kenney.nl (CC0) · Quaternius.com (CC0) · Poly Pizza (CC0) · OpenGameArt CC0 filter ·
Poly Haven / ambientCG (CC0 textures) · Mixamo (free anims) · Freesound CC0 ·
Incompetech / Free Music Archive (CC-BY music) · Google Fonts (OFL).

---

## 1. Environment — modular level kit (feeds task 11 sections)

Sections are grid-modular; the assembler sockets them at 1u = 1m. One interior kit
+ one texture set covers the whole Bank archetype and the shared Museum/Warehouse.

| Need (real section IDs) | Footprint | Source pack | License |
|---|---|---|---|
| Walls / floors / doorways / stairs (all sections) | grid | **Kenney — Modular Buildings** / **Kenney — City Kit (Commercial)** | CC0 |
| `bank_entry_lobby`, `bank_teller_hall` — counters, desks, ropes | 2×2–3×2 | **Kenney — Furniture Kit** + **Quaternius — Ultimate Furniture** | CC0 |
| `bank_office` — desks, chairs, cabinets, PCs | 2×2 | **Kenney — Furniture Kit** | CC0 |
| `bank_server_room` / `data_server` — server racks | 2×2 | **Poly Pizza** "server rack" · **Quaternius — Sci-Fi** | CC0 |
| `bank_vault` (3×3 setpiece) — vault door, shelving | 3×3 | **Poly Pizza** "vault door" · **Kenney — Modular Buildings** | CC0 |
| `bank_loading_dock` — crates, shutters, pallets | 3×2 | **Kenney — Warehouse / Survival Kit** | CC0 |
| Museum archetype dressing — pedestals, frames | shared | **Poly Pizza** "museum/pedestal" | CC0 |
| Warehouse archetype dressing — shelving, forklifts | shared | **Kenney — Warehouse Kit** | CC0 |
| Wall/floor materials (concrete, marble, carpet, tile) | — | **ambientCG** / **Poly Haven** (recolor to palette) | CC0 |
| Prototype grid textures (greybox interim) | — | **Kenney — Prototype Textures** | CC0 |

---

## 2. Characters — one shared humanoid rig (feeds task 05)

Pick **one rig** and share its animation set across all actors (FR-18-5). Quaternius
modular humans + Mixamo retargeting is the standard low-effort path.

| Need (real enemy IDs) | Look | Source | License |
|---|---|---|---|
| Player first-person arms/hands | gloved hands | **Quaternius — Ultimate Modular Men** (arms) or **Kenney — Blocky Characters** | CC0 |
| `guard` (default_guard) | security uniform, blue | **Quaternius — Ultimate Modular Characters** | CC0 |
| `inspector` (gold, keycard carrier) | suit/distinct color | recolor of base rig | CC0 |
| `responder` | patrol cop | recolor + cap accessory | CC0 |
| `swat` | tac vest/helmet | **Quaternius — Modular Characters** (armored variant) | CC0 |
| `specialist_shield` | riot shield | base rig + **Poly Pizza** "riot shield" | CC0 |
| `specialist_sniper` | marksman | recolor of base rig | CC0 |
| Civilian (pickpockable marker) | casual clothes | **Quaternius / Kenney — Blocky Characters** | CC0 |
| Downed `Body` | reuse rig, ragdoll/pose | shared rig | CC0 |
| **Animations** (idle, patrol walk, alert, aim, fire, hit, death, drag) | — | **Mixamo** (retarget to the chosen rig) | free |

---

## 3. Obstacle & security props (feeds task 06)

One prop per obstacle def — these replace the tinted greybox boxes directly.

| Obstacle ID | Prop | Source | License |
|---|---|---|---|
| `lock_basic` | padlock / door handle | Poly Pizza "padlock" | CC0 |
| `keycard_door` / `keypad_door` | card reader + keypad panel | **Kenney — furniture/tech** · Poly Pizza "keypad" | CC0 |
| `elock_basic`, `biometric_lock`, `biometric_spoof` | wall panel + scanner | Poly Pizza "keypad/scanner" | CC0 |
| `camera_ptz` | CCTV dome/PTZ camera | **Poly Pizza** "security camera" | CC0 |
| `laser_grid` | emitter posts (beams = shader) | Kenney sci-fi prop + emissive shader | CC0 |
| `motion_sensor`, `pressure_plate` | ceiling/floor sensor | Poly Pizza "motion sensor" | CC0 |
| `fuse_box`, `junction_box`, `light_switchable` | electrical panel | Poly Pizza "fuse box / breaker" | CC0 |
| `safe_basic` | floor safe | **Poly Pizza** "safe" | CC0 |
| `display_case` | glass case | Kenney furniture + transparent mat | CC0 |
| `silent_alarm` | wall alarm/strobe | Poly Pizza "alarm" | CC0 |
| `breach_vault` (drill target) | reinforced vault door | Poly Pizza "vault door" | CC0 |

---

## 4. Loot & bags (feeds task 08)

| Loot ID | Prop | Source | License |
|---|---|---|---|
| `cash_bundle` | cash stacks | **Kenney — Money** / Poly Pizza "cash" | CC0 |
| `gold_bar` | gold bar | Poly Pizza "gold bar" | CC0 |
| `masterpiece_painting` | framed painting | Poly Pizza "painting/frame" | CC0 |
| `jewelry_case` | jewelry / gems | **Kenney — Generic Items** · Poly Pizza "diamond" | CC0 |
| `stolen_data` | hard drive / documents | Poly Pizza "hard drive" | CC0 |
| Loot bag / thrown bag / dropped bag | duffel bag | **Poly Pizza** "duffel bag" | CC0 |

---

## 5. Gear, gadgets & weapons (feeds task 09)

### Tools & gadgets (26 GearDefs)
Most are held/HUD items — many only need a **UI icon** (see §7), not a full 3D model.
World models needed for the ones the player deploys:

| Gear ID | Needs | Source | License |
|---|---|---|---|
| `drill`, `thermite`, `c4` | deployable world models | Poly Pizza "power drill / charge" · Kenney tools | CC0 |
| `emp`, `smoke`, `noisemaker`, `throwing_coins`, `aerosol` | small throwables | Kenney — Generic Items | CC0 |
| `lockpick_set`, `lockpick_gun`, `hacking_rig`, `stethoscope`, `glasscutter`, `keycard_cloner`, `casing_visor`, `body_bag`, `get_out_of_jail`, `soft_soled_gear` | **icon only** for now | Kenney — Game Icons (see §7) | CC0 |
| `armor_plates` | body-armor viewmodel | Quaternius character armor variant | CC0 |

### Weapons (low-poly modern firearms)
| Weapon ID | Source | License |
|---|---|---|
| `suppressed_pistol`, `dart_gun` | **Quaternius — Guns pack** (pistol) | CC0 |
| `smg`, `rifle`, `shotgun` | **Quaternius — Guns pack** · OpenGameArt "low poly modern weapons" (CC0 filter) | CC0 |
| `suppressor` (attachment) | modeled as pistol variant or small mesh | CC0 |

> Note: Kenney's gun assets are sci-fi "Blaster Kit"; for grounded modern firearms
> prefer **Quaternius Guns** or an OGA CC0 modern-weapons pack. Log as ART-TODO if
> the only on-hand option is stylized.

---

## 6. Audio (feeds task 17)

| Need | Source | License |
|---|---|---|
| Dynamic music layers (calm → tense → combat → resolution) | **Incompetech** / **Free Music Archive** (heist/tension tracks) | CC-BY* |
| Gunshots, reload, suppressed shots | **Freesound** (CC0 filter) · Kenney — impact/digital audio | CC0 |
| Lockpick tension/snap, drill run/jam, hack progress/fault | Freesound (CC0) | CC0 |
| Alarm, spotted-sting, takedown | Freesound (CC0) · Kenney — Interface | CC0 |
| Loot bagged/secured, pickup | **Kenney — Interface Sounds / Digital Audio** | CC0 |
| Footsteps (per surface), radios | Freesound (CC0) | CC0 |
| Ambience (room tone, HVAC, street) | Freesound (CC0) | CC0 |
| UI clicks/hovers | **Kenney — Interface Sounds** | CC0 |

\* CC-BY music → must be listed in `CREDITS.md`.

---

## 7. UI, icons & fonts (feeds task 15)

| Need | Source | License |
|---|---|---|
| HUD widgets, panels, buttons, frames | **Kenney — UI Pack** / **UI Pack: RPG Expansion** | CC0 |
| Gear/loot/edge/perk/attribute icons (all IDs in §5, edges ×20, perks ×8, attributes ×14) | **Kenney — Game Icons** + **Game Icons Expansion** (~500 icons) | CC0 |
| Detection eye / noise-ring / carry / pursuit HUD glyphs | Kenney — Game Icons · **Game-icons.net** | CC0 / CC-BY |
| Minigame overlay art (lockpick arc, safe dial, hack nodes, keypad, drill gauge) | build from Kenney UI Pack shapes | CC0 |
| Primary UI font | **Google Fonts** — Barlow / Inter / Oswald (heist-poster vibe) | OFL |
| Display/heading font | **Kenney — Kenney Future** / Google Fonts — Oswald | CC0 / OFL |

---

## Import order (recommended)

1. **Env kit + textures** (§1) — biggest visual payoff; unblocks every mission.
2. **One character rig + Mixamo anims** (§2) — turns capsules into guards.
3. **Obstacle + loot props** (§3, §4) — makes the heist legible.
4. **UI kit + icons + font** (§7) — feeds the HUD/menu build (task 15).
5. **Audio** (§6) — feeds task 17.
6. **Weapons + gadget models** (§5) — needed once loud combat gets its art pass.

Groups 1–4 alone dress the M2 vertical-slice Bank to shippable quality (FR-18-7).
Kenney + Quaternius + Mixamo cover ~85% of this catalog in one cohesive style.
