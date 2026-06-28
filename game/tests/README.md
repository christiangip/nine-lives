# Tests (GUT)

Automated tests use the **GUT** framework (Godot Unit Test).

## Setup (one-time)
1. Install GUT via the Godot AssetLib, or add it as a submodule under `addons/gut`.
2. Enable the plugin: Project → Project Settings → Plugins → GUT → Enable.

## Run
- **Editor:** open the GUT panel, point it at `game/tests/`, Run All.
- **CLI / CI:** `godot --headless -s addons/gut/gut_cmdln.gd -gconfig=game/tests/.gutconfig.json`

## Conventions
- One test file per system: `test_<system>.gd`, methods `test_*`.
- Unit tests in `tests/unit/`; cross-system in `tests/integration/`.
- Each sub-system task list names the exact tests that gate "Definition of Done."
