#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
export PATH="$repo/build:$PATH"
mkdir -p "$repo/evidence"
bin="$repo/build/vectoradd_harness"
for f in "$bin" "$repo/build/instr_count.so" "$repo/build/mem_trace.so" "$repo/build/resolve_delay.so"; do
  test -f "$f" || { echo "Missing $f" >&2; exit 1; }
done
command -v cuobjdump >/dev/null || { echo 'cuobjdump is required on PATH' >&2; exit 1; }
command -v nvdisasm >/dev/null || { echo 'nvdisasm is required on PATH' >&2; exit 1; }

"$bin" 256 > "$repo/evidence/baseline_wsl.log" 2>&1
env NOBANNER=1 LD_PRELOAD="$repo/build/instr_count.so" \
  "$bin" 16 > "$repo/evidence/instr_count.log" 2>&1
env NOBANNER=1 LD_PRELOAD="$repo/build/mem_trace.so" \
  "$bin" 16 > "$repo/evidence/mem_trace.log" 2>&1
env NOBANNER=1 RESOLVE_DELAY_CYCLES=5000 \
  LD_PRELOAD="$repo/build/resolve_delay.so" \
  "$bin" 256 > "$repo/evidence/delay.log" 2>&1

for log in baseline_wsl instr_count mem_trace delay; do
  test "$(grep -c 'original_reduced=PASS repeat=PASS cpu=PASS' "$repo/evidence/$log.log")" -eq 3
done
grep -q 'Total app instructions:' "$repo/evidence/instr_count.log"
grep -q 'MEMTRACE:.*LDG' "$repo/evidence/mem_trace.log"
grep -q 'delay instrumented vecAdd' "$repo/evidence/delay.log"
echo 'All four runs passed the bytewise comparisons.'
