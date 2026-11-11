#!/usr/bin/env bash
set -euo pipefail

# Compile on the Mac with the user's Kuiper Docker image; GPU execution is on WSL2.
repo=$(cd "$(dirname "$0")/.." && pwd)
: "${NVBIT_ROOT:?Set NVBIT_ROOT to the extracted NVBit 1.8.1 directory}"
: "${CMAKE_HOME:?Set CMAKE_HOME to a Linux x86_64 CMake 3.29+ directory}"
image=${KUIPER_IMAGE:-kuiper-pldi2026:latest}
mkdir -p "$repo/build"

docker run --rm --platform linux/amd64 \
  -v "$repo:/repo" -v "$NVBIT_ROOT:/sdk:ro" -v "$CMAKE_HOME:/cmake:ro" \
  --entrypoint /bin/bash "$image" -lc '
set -euo pipefail
export PATH=/cmake/bin:$PATH
echo "41df3c1d764384bc5d6700a7ac2cb99e052174d548b8fda62bc39a1f8842d3ab  /sdk/test-apps/vectoradd/vectoradd.cu" | sha256sum -c -
nvcc -O2 -std=c++17 -arch=sm_86 -cudart=static \
  -I/sdk/test-apps/vectoradd -o /repo/build/vectoradd_harness \
  /repo/src/vectoradd_harness.cu
cp /usr/bin/cuobjdump /repo/build/cuobjdump
cmake -S /sdk/tools/instr_count -B /repo/build/instr_count \
  -DNVBIT_TOOL_CUDA_ARCHITECTURES=86 -DCMAKE_CUDA_ARCHITECTURES=86
cmake --build /repo/build/instr_count -j2
cmake -S /sdk/tools/mem_trace -B /repo/build/mem_trace \
  -DNVBIT_TOOL_CUDA_ARCHITECTURES=86 -DCMAKE_CUDA_ARCHITECTURES=86
cmake --build /repo/build/mem_trace -j2
cmake -S /repo/src/nvbit_delay -B /repo/build/resolve_delay \
  -DNVBIT_ROOT=/sdk -DNVBIT_TOOL_CUDA_ARCHITECTURES=86 \
  -DCMAKE_CUDA_ARCHITECTURES=86
cmake --build /repo/build/resolve_delay -j2
'

cp "$repo/build/instr_count/instr_count.so" "$repo/build/instr_count.so"
cp "$repo/build/mem_trace/mem_trace.so" "$repo/build/mem_trace.so"
cp "$repo/build/resolve_delay/resolve_delay.so" "$repo/build/resolve_delay.so"
shasum -a 256 "$repo"/build/{vectoradd_harness,instr_count.so,mem_trace.so,resolve_delay.so}
