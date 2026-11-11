#include <stdint.h>

// A bounded, lane-dependent delay before each predicated global-memory SASS
// instruction. The injected routine does not read or change app memory.
extern "C" __device__ __noinline__ void delay_memory(int pred, uint32_t cycles) {
    if (!pred) return;
    const uint64_t start = clock64();
    const uint64_t duration = uint64_t(cycles) * (1 + (threadIdx.x & 3));
    while (clock64() - start < duration) {
        asm volatile("");
    }
}
