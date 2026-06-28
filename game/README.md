# Nine Lives — Godot project root

Open this folder (`game/`'s parent) in **Godot 4.6 (Forward+)**. `project.godot`
is at the repo root. Autoloads are wired in `[autoload]` there and live in
`game/autoload/`.

- **Code:** `game/systems/` (by domain) + `game/scenes/` (scene-local scripts).
- **Content (data-driven):** `game/resources/` (.tres instances of the `_defs/`
  classes) and `game/data/` (JSON). Add content WITHOUT touching code.
- **Levels:** `game/prefabs/` hand-authored modular sections + setpieces.
- **Tests:** `game/tests/` (GUT). See `game/tests/README.md`.

First run: `game/scenes/main/Main.tscn` → Main Menu. See docs/ for everything.
