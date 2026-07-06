# CONTENT PACKS — bundling & enabling expansions

A **content pack** bundles related content (an archetype, edges, gear, a station, sections, …) into one
folder that can be **enabled or disabled** — the unit of an expansion or mod (FR-19-4). A pack ships as
**data + scenes only**; enabling it makes its content flow into the same registries by `id`, with **zero
core code change**. For authoring the content itself see [AUTHORING.md](AUTHORING.md) and
[PREFAB_AUTHORING.md](PREFAB_AUTHORING.md).

## Anatomy of a pack
```
game/packs/<pack_id>/
  pack.json                 # the manifest (below)
  loot/*.tres               # category subfolders, named by the registry key
  gear/*.tres
  edges/*.tres
  archetypes/*.tres
  sections/*.tres           # SectionDefs  (core's own folder is prefabs_meta/, but packs use sections/)
  stations/*.tres
  scenes/*.tscn|*.gd        # e.g. a station's panel scene (a scene may carry a script)
  <key>.json                # optional bulk-JSON per category (parity with data/economy.json)
```
Subfolders are named by the **registry key** (`loot`, `gear`, `edges`, `sections`, `stations`,
`archetypes`, `objectives`, `modifiers`, `enemies`, `attributes`, `intel`, …). Only the subfolders you
ship are scanned; omit the rest.

### The manifest — `pack.json`
```json
{
  "id": "estate_job",
  "name": "The Estate Job",
  "version": "1.0",
  "description": "…",
  "requires": [],
  "default_enabled": false
}
```
`id` is required and unique. `default_enabled` (default `true`) is the state a freshly-installed pack
takes until the player toggles it. `requires` is reserved for pack dependencies.

## Enabling / disabling
[`PackManager`](../game/systems/content/PackManager.gd) (a pure-static global, like `Services`) discovers
`res://game/packs/*/pack.json`, tracks enable state in **`user://packs.json`** (deliberately *outside*
the save slots — a disabled pack can never brick a save, and the choice survives save deletion), and
hands each enabled pack's `<key>/` folders to `Content._make()`.

- `PackManager.is_enabled(id)` / `PackManager.installed()` — read state.
- `PackManager.set_enabled(id, on)` — persist the choice **and** rebuild the registries live via
  `Content.reload()`, so the change is visible immediately.

The **Expansion Sandbox** ([game/scenes/expansion/ExpansionSandbox.tscn](../game/scenes/expansion/ExpansionSandbox.tscn),
in the gallery hub) is a first-person demo of the whole loop: `[P]` toggles the shipped pack and the live
registry counts jump; `[V]` runs the validator; `[G]` grants pack unlocks to show forward-compat.

## Semantics you can rely on
- **Add-only.** The core content folder is scanned first, so on an `id` collision the **base game wins**
  (first-writer-wins, `ContentRegistry.duplicate_ids`). A pack can *add* content but cannot silently
  *override* a base id. (Intentional override is a possible future extension.)
- **No recompile.** GDScript has no build step; dropping a pack folder in and enabling it is enough. A
  pack may include its own `.gd`/`.tscn` (e.g. a station panel) — that's still "data + scenes," not a
  core edit. A new Hideout station is exactly a `StationDef` + its panel scene (FR-19-7).
- **Forward-compatible saves (preserve-but-dormant).** If a save references content from a pack that is
  later disabled/removed, the ids are **kept verbatim** in the permanent account + the Streak; gameplay
  safely skips what it can't resolve (never crashes); **re-enabling the pack revives everything** with no
  data loss. Nothing is stripped. [`SaveReconcile.unknown_ids()`](../game/systems/content/SaveReconcile.gd)
  *reports* dormant ids (for the sandbox/tests) — it never mutates state. No save-schema bump is needed.

## Validate your pack
`bash tools/scripts/validate_content.sh` validates the base game **plus every enabled pack** — required
fields, id uniqueness + `lowercase_snake` format, dangling cross-references, and economy ranges. It's the
CI content gate. In-editor, *File ▸ Run*
[tools/godot/ValidateContentEditor.gd](../tools/godot/ValidateContentEditor.gd) for the structural checks.

## Worked example — "The Estate Job"
[game/packs/estate_job/](../game/packs/estate_job/) is a complete, data-only stealth expansion that
installs by dropping the folder in: a `estate` archetype (reusing existing objectives/enemies/loot), four
new `SectionDef`, three Edges (reusing real modifier keys `shadow_fill_mult` / `footstep_noise_mult` /
`notoriety_mult`), a `estate_snips` gadget (reuses the `glasscutter` capability flag — zero code), and a
`locksmith` station (a `StationDef` + its own `LocksmithPanel` scene subclassing the shared
`StationPanel`). It ships **disabled** (`default_enabled: false`) so the base game is unchanged until you
enable it. See the tests [test_pack_toggle.gd](../game/tests/integration/test_pack_toggle.gd) and
[test_addcontent_no_code.gd](../game/tests/integration/test_addcontent_no_code.gd).

## Scope note — where packs load from
Today packs load from **`res://game/packs/`** (in-project). The loader is built so an external
**`user://packs/`** mod root can be added later as one extra scan root. Caveat for that future step:
Godot imports scenes/models at build time, so a `user://` drop-in can only ship **data-only** content
(`.tres`/JSON referencing already-imported assets); scene- or model-bearing mods need the editor's import
step. This is why the shipped worked example lives under `res://`.
