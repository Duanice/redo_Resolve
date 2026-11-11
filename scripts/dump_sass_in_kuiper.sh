#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
binary=${BINARY:-"$repo/build/vectoradd_harness"}
image=${KUIPER_IMAGE:-kuiper-pldi2026:latest}
test -f "$binary" || { echo "Missing $binary" >&2; exit 1; }
mkdir -p "$repo/evidence"

docker run --rm --platform linux/amd64 -v "$binary:/kernel:ro" \
  --entrypoint /bin/bash "$image" -lc \
  'cuobjdump --dump-sass /kernel' > "$repo/evidence/vectoradd_sm86.sass"
grep -q 'Function : _Z6vecAddPdS_S_i' "$repo/evidence/vectoradd_sm86.sass"
grep -q 'Function : _Z13vecAddReducedPKdS0_Pdi' "$repo/evidence/vectoradd_sm86.sass"
shasum -a 256 "$binary"
echo "SASS saved to $repo/evidence/vectoradd_sm86.sass"
