# redo_Resolve

An executed, small case study of the **testing → reduction → proof** workflow in
[RESOLVE: Language-Agnostic Validation of GPU Kernels Through Testing, Reduction, and Proof](https://arxiv.org/abs/2610.05683).
The real operator is NVIDIA NVBit 1.8.1's `test-apps/vectoradd/vectoradd.cu`.
Its original CUDA kernel is included unchanged at build time in
[`src/vectoradd_harness.cu`](src/vectoradd_harness.cu), alongside a serial
`vecAddReduced` candidate. This reproduces the workflow with a small operator;
it does **not** reproduce the paper's exact GPU binaries or H100 measurements.

## Executed results

The GPU was a Windows RTX 3060 Laptop (6 GiB), exposed to WSL2 Ubuntu 24.04
x86_64, with NVIDIA driver 616.92. The Kuiper Docker image on a Mac provided
CUDA 12.0.140 compilation and F*/Pulse verification. NVBit 1.8.1 instrumented
the `sm_86` binaries on WSL2. Binary hashes are in
[`evidence/environment.log`](evidence/environment.log).

| Stage | Result | Raw evidence |
| --- | --- | --- |
| Baseline | Three input families × four runs at 256 doubles: original/reduced, repeats, and CPU all bytewise equal | [`baseline_wsl.log`](evidence/baseline_wsl.log) |
| SASS count | NVBit `instr_count`: 202 original vs 112 reduced warp-level dynamic instructions at 16 doubles; 3,768 across 24 launches | [`instr_count.log`](evidence/instr_count.log) |
| Memory trace | NVBit `mem_trace`: 24 launches; each reads 32 doubles and writes 16; paired kernels read the same addresses and write separate buffers | [`mem_trace.log`](evidence/mem_trace.log) |
| Timing perturbation | Custom NVBit tool delays predicated global-memory SASS operations by 5,000 clock cycles × lane factor 1–4; all bytewise checks pass at 256 doubles | [`delay.log`](evidence/delay.log) |
| Proof | Kuiper/F*/Pulse verifies double-add approximation and a `gpu_ref` cell read/read/write contract | [`proof.log`](evidence/proof.log) |

The **static SASS disassembly** for both kernels is
[`evidence/vectoradd_sm86.sass`](evidence/vectoradd_sm86.sass):
`_Z13vecAddReducedPKdS0_Pdi` starts near line 19, and the unchanged tutorial
`_Z6vecAddPdS_S_i` starts near line 488. It was dumped with `cuobjdump
--dump-sass` from the **tested** binary with SHA-256
`2de0064dcb0413c2d23f819d4b3845eff13b17dfa9eac851fea21fd283d16202`.
The dynamic counts and addresses are in the NVBit logs above.

`scripts/analyze_mem_trace.py` mechanically checks all 12 trace pairs. SASS
counts are NVBit's default **warp-level** counts. The timing perturbation
changes execution order opportunities, but this race-free vector add should
remain deterministic. The formal proof covers **one element**; the vector-wide
mapping, bounds, and equivalence of both compiled binaries have test and trace
evidence, but no complete formal proof. Bytewise equality is observed on the
listed inputs, not universally established.

## Build on the Mac

Prerequisites: `kuiper-pldi2026:latest` Docker image,
[NVBit 1.8.1](https://github.com/NVlabs/NVBit/releases/tag/v1.8.1), and
[CMake 3.31.10 Linux x86_64](https://github.com/Kitware/CMake/releases/tag/v3.31.10).
The NVBit tarball SHA-256 is
`9c383591bc62be02dd0bcba51f98320525817de67d30d997ec3d618adcd3d618`;
the original tutorial source SHA-256 is
`41df3c1d764384bc5d6700a7ac2cb99e052174d548b8fda62bc39a1f8842d3ab`.

```bash
mkdir -p third_party
curl -fL https://github.com/NVlabs/NVBit/releases/download/v1.8.1/nvbit-Linux-x86_64-1.8.1.tar.bz2 -o third_party/nvbit.tar.bz2
echo '9c383591bc62be02dd0bcba51f98320525817de67d30d997ec3d618adcd3d618  third_party/nvbit.tar.bz2' | shasum -a 256 -c -
tar -xjf third_party/nvbit.tar.bz2 -C third_party
curl -fL https://github.com/Kitware/CMake/releases/download/v3.31.10/cmake-3.31.10-linux-x86_64.tar.gz -o third_party/cmake.tar.gz
tar -xzf third_party/cmake.tar.gz -C third_party
NVBIT_ROOT="$PWD/third_party/nvbit_release_x86_64" CMAKE_HOME="$PWD/third_party/cmake-3.31.10-linux-x86_64" bash scripts/build_in_kuiper.sh
bash scripts/dump_sass_in_kuiper.sh
bash scripts/verify_in_kuiper.sh
```

The NVBit distribution remains under ignored `third_party/`; the generated
binaries are under ignored `build/`. Neither is committed to Git. The build
script produces `vectoradd_harness`, `instr_count.so`, `mem_trace.so`,
`resolve_delay.so`, and `cuobjdump` in `build/`.

## Run on the WSL2 GPU

Copy those five build files to this repository's `build/` directory on WSL2.
NVBit additionally requires `nvdisasm` on `PATH`. For this run, it was
extracted from NVIDIA's standalone Ubuntu 24.04 package without changing the
Windows driver:

```bash
curl -fL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-nvdisasm-12-8_12.8.55-1_amd64.deb -o build/nvdisasm.deb
echo 'ad0942545c1e6ec81b1d2ed86efe23e14be72530ef3f3f8433a117589a516441  build/nvdisasm.deb' | sha256sum -c -
dpkg-deb -x build/nvdisasm.deb build/nvdisasm_pkg
ln -s nvdisasm_pkg/usr/local/cuda-12.8/bin/nvdisasm build/nvdisasm
bash scripts/run_on_gpu.sh
python3 scripts/analyze_mem_trace.py evidence/mem_trace.log
```

`run_on_gpu.sh` checks the three PASS lines for every stage and exits on
failure. The 16-element trace is small enough to inspect. Inputs are integer,
exact cancellation, and `sin² + cos²` values. Both GPU output arrays start
with `0xa5` bytes, so unwritten elements cause a comparison failure.

## Provenance and scope

The unchanged NVIDIA tutorial source and its official `instr_count` and
`mem_trace` tools are loaded from the pinned NVBit distribution at build time.
The custom delay tool is in [`src/nvbit_delay`](src/nvbit_delay); the verified
per-element model is in [`proof/Kuiper.VectorAdd.fst`](proof/Kuiper.VectorAdd.fst).
The paper's own kernel binaries and full verification artifact were not used;
the “original” binary tested here was compiled from NVIDIA's tutorial source.
