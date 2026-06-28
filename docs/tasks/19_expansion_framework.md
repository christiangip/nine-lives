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
- [ ] "Add a new ___" templates + sample files for loot/gear/edge/perk/archetype/objective/modifier/enemy/station/intel.
- [ ] A prefab-authoring guide documenting sockets/anchors/cover/patrol tags.

### Phase 19.2 — Validator
- [ ] Content validator (required fields, id uniqueness, reference integrity, range checks); CLI + editor tool; CI hook.

### Phase 19.3 — Content packs
- [ ] Pack manifest + enable/disable; registry scoping; save forward-compat handshake (16).

### Phase 19.4 — Worked example
- [ ] Ship one small "expansion pack" (e.g. a new archetype + 3 Edges + 1 station + 1 gear) entirely as data to prove the loop.

## Tests (GUT)
- `test_addcontent_no_code.gd` — enabling a pack folder surfaces its content via registries with no code change.
- `test_content_validator.gd` — malformed content (missing field, dup id, dangling ref) is rejected with a clear message.
- `test_pack_toggle.gd` — disabling a pack removes its content cleanly; saves referencing it still load.

## Definition of Done
- [ ] FR-19-1..7 satisfied; phases checked; tests green.
- [ ] The worked-example expansion installs by dropping in a folder — no recompile.
