# Testing Strategy

"Done" in this project means **the tests named in the task list pass**. Every sub-system task list ends with a Tests section and a Definition of Done that references concrete test files.

## Framework

**GUT** (Godot Unit Test). Install into `addons/gut/` (AssetLib or git submodule) and enable the plugin. Config: `game/tests/.gutconfig.json`. Layout: `game/tests/unit/` (isolated logic), `game/tests/integration/` (cross-system), `game/tests/helpers/` (fixtures).

## Running

- **Editor:** GUT panel → Run All.
- **CLI / CI:** `bash tools/scripts/run_tests.sh` (wraps `godot --headless -s addons/gut/gut_cmdln.gd -gconfig=game/tests/.gutconfig.json -gexit`).
- CI runs the suite on every push/PR (`.github/workflows/ci.yml`).

## What we test (and what we don't)

We favor testing **deterministic logic** that holds the design's promises:

- **Pure rules & math** — carry caps, Notoriety/Heat/Legacy formulas, economy costs, detection accumulation math, generation solvability. *Unit-tested, high value.*
- **State machines** — detection state transitions, Pursuit phases, save/load round-trips, Streak lifecycle. *Unit/integration.*
- **Invariants** — "every generated layout is solvable," "secured loot survives a Catch," "Continue is disabled iff zero saves." *Integration, gate CI.*
- **Feel / rendering / audio mix** — *not* unit-tested; verified by a manual playtest checklist per milestone (see below).

## Test-first for rules

For anything with a number or a rule, write the GUT test **from the functional requirement before** the implementation (the carry and save examples already in `game/tests/unit/` are templates). A failing/`pending` spec is a valid checked-in TODO that encodes the requirement.

## Determinism harness

Generation tests seed `MissionGenerator` with a fixed list of seeds and assert: room connectivity, a stealth-viable nav path entry→objective→escape, reachable Drop Points, and no overlapping/blocked anchors. Seeds that ever fail are added permanently to the regression set.

## Manual playtest checklist (per milestone gate)

Each milestone (M0–M5 in the master list) has a short scripted playtest: e.g. M0 — "infiltrate the greybox, pick one lock, hack one panel, take one guard down and hide the body, bag and drop loot, extract; confirm the secured value banked." These live at the bottom of the relevant task lists and must be signed off before the gate is considered met.

## Coverage expectations

No hard percentage target. The bar is: **every functional requirement that can be expressed as a deterministic assertion has a test**, and **every CI-gating invariant is covered**. Prefer a few meaningful tests over many trivial ones.
