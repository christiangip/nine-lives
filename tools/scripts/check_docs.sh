#!/usr/bin/env bash
# Cheap sanity lint: every task list referenced by the master list must exist.
set -euo pipefail
cd "$(dirname "$0")/../.."
missing=0
while read -r f; do
  [ -f "docs/tasks/$f" ] || { echo "MISSING task list: $f"; missing=1; }
done < <(grep -oE '[0-9]{2}_[a-z_]+\.md' docs/tasks/00_MASTER_TASKLIST.md | sort -u)
[ "$missing" -eq 0 ] && echo "OK: all referenced task lists exist."
exit $missing
