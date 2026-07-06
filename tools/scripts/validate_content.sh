#!/usr/bin/env bash
# Validate all content data headlessly (task 19, FR-19-3): required fields, id uniqueness + lowercase_snake
# format, dangling cross-references, and economy value/cost/curve ranges — over the base game plus any
# enabled content packs. Exits non-zero on any violation (the CI content gate). Requires Godot 4.6 on PATH
# (see the godot-runtime note for the absolute-path fallback when bare `godot` isn't resolvable).
set -euo pipefail
godot --headless -s tools/godot/ContentValidateMain.gd
