#!/usr/bin/env bash
# Run the GUT suite headlessly. Requires Godot 4.6 on PATH and addons/gut present.
set -euo pipefail
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=game/tests/.gutconfig.json -gexit
