#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
image=${KUIPER_IMAGE:-kuiper-pldi2026:latest}
mkdir -p "$repo/evidence"
docker run --rm --platform linux/amd64 -v "$repo:/repo:ro" \
  --entrypoint /bin/bash "$image" -lc \
  'cd /home/ubuntu/kuiper && ./fstar.sh /repo/proof/Kuiper.VectorAdd.fst' \
  > "$repo/evidence/proof.log" 2>&1
grep -q 'All verification conditions discharged successfully' "$repo/evidence/proof.log"
echo 'Per-element Kuiper/Pulse proof passed.'
