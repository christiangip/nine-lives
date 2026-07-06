# PREFAB AUTHORING — the section socket/anchor contract

Third-party level sections slot into the mission generator purely as **data** (FR-11-1, FR-19-5). A
section is a `SectionDef` (`.tres`) describing a self-contained stealth space — its footprint, connection
sockets, and content anchors — read as **pure data** (the scene is never instanced) so assembly and
solvability validate headlessly. This is the contract to author against; the schema is
[game/resources/_defs/SectionDef.gd](../game/resources/_defs/SectionDef.gd).

## Fields
| Field | Meaning |
|---|---|
| `id` | Unique `lowercase_snake` `StringName`. |
| `display_name` | Human name (shown in dev tools / the sandbox board). |
| `kind` | `ENTRY` (0) · `INTERIOR` (1) · `OBJECTIVE` (2) · `SETPIECE` (3) · `ESCAPE` (4). |
| `footprint` | `Vector2i` size in **grid cells** — **1 cell = 6.0 m**. Drives overlap-free placement. |
| `socket_count` | Connection points to neighbours (matched-or-capped by the assembler, FR-11-2). |
| `security_tier` | `1` = low; higher wings host the Mark + tougher gates (the populator biases by this). |
| `anchors` | `Array[Dictionary]`, each `{ "type": StringName, "pos": Vector3 }` — where the populator scatters content (positions are local, within the footprint). |
| `scene` | Optional `PackedScene` of real geometry. **Leave null** to get a procedural `SectionShell` (a grid-snapped room with a doorway on every edge) — enough to author + playtest before art exists. |

### Anchor types
`&"entry"` (player spawn / exit) · `&"patrol"` (a guard patrol point) · `&"loot"` (loot drop) ·
`&"cover"` (cover object) · `&"objective"` (the Mark / setpiece target) · `&"drop"` (a Drop Point for
banking loot) · `&"reinforce"` (reinforcement spawn during Pursuit). Author several per section; the
populator picks among them under the archetype's designer rules.

## Minimum viable archetype
`MissionBoard.is_generatable` ([game/systems/missiongen/MissionBoard.gd](../game/systems/missiongen/MissionBoard.gd))
gates an archetype as generatable **iff its section pool resolves all of**:

- an **ENTRY** section, and
- an **ESCAPE** section, and
- at least one **INTERIOR** section, and
- an **OBJECTIVE** (or SETPIECE) section listed in `setpiece_ids`, and
- the archetype declares **≥1 `objective_ids`**.

Also include at least one `&"drop"` anchor somewhere reachable (the Drop Point) and enough `&"loot"`/
`&"patrol"` anchors for the populator to work with — the headless `MissionValidator` proves entry →
objective → escape + a reachable Drop Point before a seed is ever shown.

## Worked example — "The Estate Job" pack
The [estate_job pack](../game/packs/estate_job/) ships four `SectionDef` (all `scene = null`, so the
SectionShell renders them) that satisfy the checklist for a fully data-only archetype:

- [estate_foyer.tres](../game/packs/estate_job/sections/estate_foyer.tres) — `ENTRY`, 3×2, 3 sockets.
- [estate_study.tres](../game/packs/estate_job/sections/estate_study.tres) — `INTERIOR`, 2×2.
- [estate_servants.tres](../game/packs/estate_job/sections/estate_servants.tres) — `INTERIOR`, 2×2.
- [estate_grounds.tres](../game/packs/estate_job/sections/estate_grounds.tres) — `ESCAPE`, 3×2 (has a `drop` anchor).
- [estate_gallery.tres](../game/packs/estate_job/sections/estate_gallery.tres) — `OBJECTIVE` setpiece, 3×3 (objective + loot + drop anchors).

Compare against the authored Bank sections in
[game/resources/prefabs_meta/](../game/resources/prefabs_meta/), e.g.
[bank_vault.tres](../game/resources/prefabs_meta/bank_vault.tres). Validate your sections + archetype
with `bash tools/scripts/validate_content.sh` — it flags a dangling `section_ids`/`setpiece_ids`
reference before it ever reaches the generator.
