# AUTHORING — How to add content without code

Nine Lives is **data-driven**: every content type is a `Resource` (`*Def`) scanned at boot by a
`ContentRegistry` and indexed by its `id`. Drop a new `.tres` (or JSON object) into the right folder and
it appears in-game with **zero code changes** — this is the platform promise (GDD §18, task 02/19).

This is the "how to add a new ___" kit. For **content packs** (bundling + enable/disable) see
[CONTENT_PACKS.md](CONTENT_PACKS.md); for **level sections** see [PREFAB_AUTHORING.md](PREFAB_AUTHORING.md);
for the registry mechanics see [ARCHITECTURE.md](ARCHITECTURE.md).

## The universal recipe
1. Create a `.tres` of the matching `*Def` (schema in [game/resources/_defs/](../game/resources/_defs/))
   in that type's folder (below), with a **unique `id`** in `lowercase_snake` (a `StringName`).
2. Reference other content **by id** (never embed another Resource) — the systems resolve ids through the
   registries.
3. Run the validator (below). Ship it. No recompile — GDScript has no build step, and the registry
   discovers the file on next scan.

> **Never branch core code on a content `id`.** Branch on a *property* of the def (a `tier`, a `tag`, a
> `params` flag). New behaviour = new data + (occasionally) a new property, not an `if id == …`.

## The content types
Each row: the `*Def` schema, the folder its `.tres` go in, the required-ish fields, and the id-references
the validator resolves. Open the linked live example to copy from.

| Type | `*Def` | Folder | Key fields | Id-references | Example |
|---|---|---|---|---|---|
| Loot | `LootDef` | [resources/loot/](../game/resources/loot/) | `id`, `display_name`, `tier`, `value`, `weight`, `volume`, `special_hook`, `mesh` | — | [gold_bar.tres](../game/resources/loot/gold_bar.tres) |
| Gear/Gadget | `GearDef` | [resources/gear/](../game/resources/gear/) | `id`, `display_name`, `slot`, `tier`, `slot_cost`, `consumable`, `research_cost`, `restock_cost`, `max_count`, `params`, `scene` | — | [glasscutter.tres](../game/resources/gear/glasscutter.tres) |
| Edge | `EdgeDef` | [resources/edges/](../game/resources/edges/) | `id`, `display_name`, `description`, `rarity`, `tags`, `modifiers` | — | [ghost.tres](../game/resources/edges/ghost.tres) |
| Perk | `PerkDef` | [resources/perks/](../game/resources/perks/) | `id`, `display_name`, `legacy_cost`, `prerequisites`, `modifiers` | `prerequisites` → perks | — |
| Archetype | `ArchetypeDef` | [resources/archetypes/](../game/resources/archetypes/) | `id`, `display_name`, `security_flavor`, `min/max_sections` | `section_ids`/`setpiece_ids` → sections, `objective_ids` → objectives, `modifier_pool` → modifiers, `enemy_roster` → enemies, `loot_ids` → loot | [bank.tres](../game/resources/archetypes/bank.tres) |
| Objective | `ObjectiveDef` | [resources/objectives/](../game/resources/objectives/) | `id`, `kind`, `display_name`, `notoriety_reward`, `is_bonus`, `params` | — | — |
| Modifier | `ModifierDef` | [resources/modifiers/](../game/resources/modifiers/) | `id`, `display_name`, `difficulty_delta`, `reward_multiplier`, `effects` | — | — |
| Enemy | `EnemyDef` | [resources/enemies/](../game/resources/enemies/) | `id`, `kind`, `tier`, `vision_angle/range`, `hearing_radius`, `health`, `move_speed`, `model` | `loadout` → gear | [default_guard.tres](../game/resources/enemies/default_guard.tres) |
| Attribute | `AttributeDef` | [resources/attributes/](../game/resources/attributes/) | `id`, `display_name`, `max_level`, `cost_curve`, `effect_per_level` | — | — |
| Station | `StationDef` | [resources/stations/](../game/resources/stations/) | `id`, `display_name`, `scene_path`, `unlock_legacy_cost`, `unlock_special_loot`, `ui_hooks` | — (`unlock_special_loot` is a loot `special_hook`) | [workshop.tres](../game/resources/stations/workshop.tres) |
| Intel | `IntelDef` | [resources/intel/](../game/resources/intel/) | `id`, `display_name`, `description`, `take_cost`, `legacy_cost`, `reveals` | — | — |
| Section | `SectionDef` | [resources/prefabs_meta/](../game/resources/prefabs_meta/) | see [PREFAB_AUTHORING.md](PREFAB_AUTHORING.md) | — | [bank_vault.tres](../game/resources/prefabs_meta/bank_vault.tres) |

**Config-singleton defs** (`DetectionConfigDef`, `AIConfigDef`, `MinigameConfigDef`, `LoadoutConfigDef`,
`PursuitConfigDef`, `ProgressionConfigDef`, `EconomyConfigDef`, `AudioConfigDef`) use `id = &"default"`
and resolve to schema defaults if absent — tune them, don't multiply them.

### Reusing a capability with zero code
Many behaviours are gated by a *property flag*, not an id — so a new item can reuse an existing
capability with no code. Example: any `GearDef` whose `params` has `{"gadget_flag": &"glasscutter"}`
opens display cases via `PlayerController.has_glasscutter()`. The worked-example pack's
`estate_snips` gear does exactly this (see [CONTENT_PACKS.md](CONTENT_PACKS.md)).

## Authoring in JSON instead of .tres
A registry can also read a bulk JSON file (used for hot-editable tables like
[data/economy.json](../game/data/economy.json)). Each object's keys map to the `*Def`'s properties; enum
members may be given by name (`"tier": "BULKY"`). Typed id-reference arrays are left for the systems to
resolve. See `ContentRegistry._hydrate` in
[game/systems/core/ContentRegistry.gd](../game/systems/core/ContentRegistry.gd).

## Validate before you ship
Run the content validator — it checks required fields, id uniqueness + `lowercase_snake` format, dangling
cross-references, and economy value/cost/curve ranges, and prints clear messages:

- **CLI / CI:** `bash tools/scripts/validate_content.sh` (exits non-zero on any violation).
- **In-editor:** *File ▸ Run* [tools/godot/ValidateContentEditor.gd](../tools/godot/ValidateContentEditor.gd)
  (structural checks; prints to the Output panel).
- **Code:** `ContentValidator.validate()` →
  [game/systems/content/ContentValidator.gd](../game/systems/content/ContentValidator.gd).

New cross-reference fields should be added to `ContentValidator.REFERENCES` so they're checked too.
