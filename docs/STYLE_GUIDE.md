# Code & Scene Style Guide

Conventions that keep a data-driven Godot project legible and expansion-friendly.

## GDScript
- **Static typing everywhere** it's cheap: `var hp: int = 100`, typed params/returns. It catches content-wiring bugs early.
- **Naming:** `PascalCase` for classes/nodes/`class_name`; `snake_case` for vars/functions; `SCREAMING_SNAKE_CASE` for consts/enums values; private members prefixed `_`.
- **Signals over polling.** Cross-system comms go through `EventBus`. Local parent/child comms may use direct signals.
- **No singletons reaching sideways.** Managers talk via `EventBus` (see ARCHITECTURE.md dependency rule).
- **One `class_name` per file**, file named after the class (`GuardAI.gd` → `class_name GuardAI`).
- **Comments:** every script opens with a `##` doc comment stating its job and the task list it belongs to. Use `TODO[NN]:` tags where `NN` is the sub-task-list number so work is greppable (`rg "TODO\[05\]"`).
- **No magic numbers in logic.** Tunables live in the relevant `*Def` resource or a `data/*.json`, not hard-coded.

## Scenes
- Scene-local scripts live beside their `.tscn` under `game/scenes/...`; reusable systems live under `game/systems/...`.
- Composition over inheritance for behavior: prefer attaching components (e.g. `DetectionSensor`, `Interactable`) to nodes.
- Keep scene trees shallow and named clearly; mark exported tunables with `@export` and a sensible default.

## Content / data
- New content = a new `.tres`/JSON instance with a unique `id`. Never branch core code on a content id; branch on a *property* of the def.
- Every def has a stable `id: StringName`. Ids are lowercase_snake.

## Commits / branches
- Trunk-based-ish: `main` (green), `develop` (integration), short-lived `feature/NN-short-desc` branches named for the task list number.
- Commit messages: `NN: imperative summary` (e.g. `04: add cone-fill light modifier`). Reference the phase/checkbox when useful.
- A PR is mergeable when its task list's relevant tests pass in CI.

## Performance
- Budget AI ticks; avoid per-frame allocations in `_process`/`_physics_process`; reuse arrays; prefer `NavigationServer` queries over manual pathing. Profile before optimizing or reaching for C#.
