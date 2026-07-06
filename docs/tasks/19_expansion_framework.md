# 19 — Expansion Framework

**Milestone:** M3 · **Depends on:** 02 (data-driven core) · **Blocks:** 20
**Implements:** GDD §18 · **Decisions:** the core "add content without code" promise.

## Overview
Harden the data-driven path so the base game becomes a *platform*: new archetypes,
prefabs, gear, Edges, perks, attributes, stations, objectives, and modifiers ship as
**data + scenes**, never core rewrites. This is what makes "expansions" cheap and
safe, and is the explicit ask behind the whole project.

## Functional Requirements
- **FR-19-1** Every content type is addable via a new `.tres`/JSON (+ scene where needed) discovered by its registry (02) with **zero core code change**.
- **FR-19-2** Authoring templates/examples exist for each content type (a "how to add X" doc + a sample file).
- **FR-19-3** A **content validator** checks new content for required fields, valid ids, dangling references, and balance ranges, and reports clearly.
- **FR-19-4** Content can be grouped into **content packs** (a folder/manifest) that can be enabled/disabled, enabling expansion bundles and mods.
- **FR-19-5** Prefab sections authored by third parties slot into the generator via the documented socket/anchor contract (11).
- **FR-19-6** Save schema tolerates unknown/disabled content gracefully (forward-compat), coordinated with 16 migration.
- **FR-19-7** A new Hideout station ships as `StationDef` + scene only (13).

## Phases
### Phase 19.1 — Authoring kit
- [x] "Add a new ___" templates + sample files for loot/gear/edge/perk/archetype/objective/modifier/enemy/station/intel. *(`docs/AUTHORING.md` — each type → its `*Def`, folder, required fields, id-references + a live example .tres.)*
- [x] A prefab-authoring guide documenting sockets/anchors/cover/patrol tags. *(`docs/PREFAB_AUTHORING.md` — the SectionDef contract + the minimum-viable-archetype checklist.)*

### Phase 19.2 — Validator
- [x] Content validator (required fields, id uniqueness, reference integrity, range checks); CLI + editor tool; CI hook. *(`ContentValidator` — declarative `REQUIRED`/`REFERENCES` tables, reuses `EconomyValidator` for ranges; `tools/scripts/validate_content.sh` CLI + `ValidateContentEditor.gd` EditorScript; wired into `ci.yml`.)*

### Phase 19.3 — Content packs
- [x] Pack manifest + enable/disable; registry scoping; save forward-compat handshake (16). *(`PackManager` scans `res://game/packs/*/pack.json`, enable state in `user://packs.json`, appended into `Content._make` + `Content.reload()`; add-only. Forward-compat = **preserve-but-dormant** via `SaveReconcile` + an audit (consumers already null-tolerate; no strip, no schema bump).)*

### Phase 19.4 — Worked example
- [x] Ship one small "expansion pack" (a new archetype + 3 Edges + 1 station + 1 gear) entirely as data to prove the loop. *(`game/packs/estate_job/` — "The Estate Job": `estate` archetype + 4 SectionDefs + 3 Edges + `estate_snips` gear + `locksmith` station/panel. Installs by dropping the folder in; ships disabled by default.)*

## Tests (GUT)
- [x] `test_addcontent_no_code.gd` — enabling a pack folder surfaces its content via registries with no code change.
- [x] `test_content_validator.gd` — base validates clean; malformed content (missing field, dup id, dangling ref, bad id format) is rejected with a clear message.
- [x] `test_pack_toggle.gd` — disabling a pack removes its content cleanly; saves referencing it still load (dormant, revived on re-enable).
- [x] `test_pack_manager.gd` (seam) + `test_expansion_scenes.gd` (sandbox smoke).

## Definition of Done
- [x] FR-19-1..7 satisfied; phases checked; tests green.
- [x] The worked-example expansion installs by dropping in a folder — no recompile.

## Progress note
**Code + automated DoD complete & verified green** on Godot 4.6.3 (headless GUT **381/381**, +13 task-19
tests; `validate_content.sh` exits 0 on base content). The expansion framework is **thin additive glue +
data**, because the registry spine (task 02) already did the heavy lifting:

- **Packs (19.3, FR-19-4/1):** new pure-static **`PackManager`** (`game/systems/content/`, no 11th
  autoload) discovers `res://game/packs/<id>/pack.json`, tracks enable state in **`user://packs.json`**
  (outside the save slots), and exposes `tres_dirs_for(key)`/`json_files_for(key)`. `Content._make` appends
  those to each registry (core folder stays index 0 → **add-only**, first-writer-wins), and a new
  `Content.reload()` rebuilds live on toggle. `ContentRegistry` was **untouched** — it already looped
  multiple dirs + tracked `duplicate_ids`.
- **Validator (19.2, FR-19-3):** new pure-static **`ContentValidator`** — a superset of `EconomyValidator`
  (calls + merges it for ranges) driven by declarative **`REQUIRED`** + **`REFERENCES`** tables (branches on
  a def's *field* + target registry, never an id). Checks id present/`lowercase_snake`/unique
  (via `duplicate_ids`) + dangling cross-refs (archetype pools, `EnemyDef.loadout`, `PursuitConfigDef.tier_ladder`
  — skipping empty "none" sentinels; free-form key-item ids like `vault_keycard` and `special_hook`
  gates are intentionally excluded). CLI `tools/scripts/validate_content.sh` (headless `ContentValidateMain`)
  + `@tool` `ValidateContentEditor.gd` (validates a transient Content in-editor) + a CI step.
- **Forward-compat (19.6):** **preserve-but-dormant** (user-chosen). An audit found the codebase already
  uses the assign-then-`if def != null` idiom everywhere and `from_dict` restores ids verbatim, so a
  disabled pack's ids stay dormant and revive on re-enable with **no code change, no strip, no
  `SCHEMA_VERSION` bump**. New read-only **`SaveReconcile.unknown_ids()`** *reports* dormant ids (sandbox +
  `test_pack_toggle`); it never mutates.
- **Authoring kit (19.1, FR-19-2/5):** `docs/AUTHORING.md` (per-type "add a new ___" using the real
  `.tres` as samples), `docs/PREFAB_AUTHORING.md` (SectionDef socket/anchor contract + generatability
  checklist), `docs/CONTENT_PACKS.md` (pack format, enable/disable, add-only, forward-compat, the `user://`
  mod caveat).
- **Worked example (19.4, FR-19-7):** `game/packs/estate_job/` "The Estate Job" — an `estate` archetype
  (reuses existing objectives/enemies/loot), **4 new `SectionDef`** (null-scene → SectionShell; exercises
  FR-19-5 through the pack), **3 Edges** reusing real modifier keys, `estate_snips` gear reusing the
  `glasscutter` capability flag (zero code), and a `locksmith` station = `StationDef` + its own
  `LocksmithPanel` (subclasses the shared `StationPanel`; surfaced by `HideoutManifest` with no central
  switch → FR-19-7). Ships **disabled by default** so the base game + existing tests are unperturbed.
- **Demo:** `game/scenes/expansion/ExpansionSandbox.tscn` (+ `ExpansionSandboxDebug.gd`, in the gallery
  hub) — an FP "Content Lab" dressed with real Quaternius furniture + heist props + an NPC: `[P]` toggles
  the pack and the live `Content.<reg>.size()` counts jump; `[V]` runs the validator; `[G]` grants pack
  unlocks then disabling shows the dormant-id count (forward-compat); the Locksmith prop opens the pack's
  own panel. Isolates its toggles to `user://packs_sandbox.json` and restores clean state on exit.

**EventBus stayed frozen** (no new signals — pack toggles are direct calls, validation is pure static).
**F6 "feel" playtest signed off 2026-07-06** (`ExpansionSandbox.tscn`): walking up to props, `[P]`
toggles "The Estate Job" pack and the live registry counts jump with no code change, `[V]` shows a clean
validator report, `[G]` then `[P]` (off) demonstrates dormant-then-revived forward-compat, and the
Locksmith prop opens the pack's own panel — **Task 19 complete (`[x]`).**
