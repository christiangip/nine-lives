#!/usr/bin/env bash
# Asset hygiene gate (task 18, FR-18-3/6). Fails CI if:
#   1. a binary asset under game/assets/ has no row in ASSET_MANIFEST.csv (exact path or a covering "dir/" row),
#   2. a binary asset is not Git-LFS tracked (per .gitattributes),
#   3. a manifest row points at a file/dir that no longer exists (stale row).
# Mirrors check_docs.sh: accumulate failures in a counter, echo a summary, exit that count (0 = pass).
set -euo pipefail
cd "$(dirname "$0")/../.."

MANIFEST="game/assets/ASSET_MANIFEST.csv"
fail=0

[ -f "$MANIFEST" ] || { echo "MISSING $MANIFEST"; exit 1; }

# Binary asset extensions — mirror the LFS patterns in .gitattributes.
exts="glb gltf bin obj fbx png jpg jpeg webp hdr exr ogg wav mp3 ttf otf"
find_expr=()
for e in $exts; do
  find_expr+=(-iname "*.$e" -o)
done
unset 'find_expr[${#find_expr[@]}-1]'   # drop trailing -o

# Manifest asset_path column (col 1) of every non-header, non-blank row.
mapfile -t rows < <(tail -n +2 "$MANIFEST" | cut -d',' -f1 | sed 's/[[:space:]]*$//' | grep -v '^$' | grep -v '^#')

covered() {
  local path="$1" row
  for row in "${rows[@]}"; do
    if [[ "$row" == */ ]]; then
      [[ "$path" == "$row"* ]] && return 0
    else
      [[ "$path" == "$row" ]] && return 0
    fi
  done
  return 1
}

# Gather every binary asset once (NUL-safe).
mapfile -d '' -t files < <(find game/assets -type f \( "${find_expr[@]}" \) -print0)

# LFS check for ALL files in a single git call (one git spawn per file is far too slow on Windows).
declare -A not_lfs
if [ "${#files[@]}" -gt 0 ]; then
  while IFS= read -r line; do
    path="${line%%: filter: *}"
    val="${line##*: filter: }"
    [ "$val" = "lfs" ] || not_lfs["$path"]=1
  done < <(printf '%s\n' "${files[@]}" | git check-attr filter --stdin)
fi

# 1 + 2: every binary asset is covered by a manifest row AND LFS-tracked.
for f in "${files[@]}"; do
  rel="${f#./}"
  if ! covered "$rel"; then
    echo "MISSING manifest row: $rel"
    fail=$((fail + 1))
  fi
  if [ -n "${not_lfs[$rel]:-}" ]; then
    echo "NOT LFS-tracked: $rel"
    fail=$((fail + 1))
  fi
done

# 3: every manifest row points at something that still exists.
for row in "${rows[@]}"; do
  if [[ "$row" == */ ]]; then
    [ -d "$row" ] || { echo "STALE manifest row (no such dir): $row"; fail=$((fail + 1)); }
  else
    [ -e "$row" ] || { echo "STALE manifest row (no such file): $row"; fail=$((fail + 1)); }
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "OK: every binary asset has a manifest row + LFS tracking; no stale rows."
fi
exit "$fail"
