#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unordered_set>
#include <vector>

#include "nvbit_tool.h"
#include "nvbit.h"

static uint32_t cycles = 5000;
static std::unordered_set<CUfunction> instrumented;

void nvbit_at_init() {
    const char* setting = getenv("RESOLVE_DELAY_CYCLES");
    if (setting) {
        char* end = nullptr;
        const unsigned long value = strtoul(setting, &end, 10);
        if (!end || *end || value > 1000000UL) {
            fprintf(stderr, "RESOLVE_DELAY_CYCLES must be 0..1000000\n");
            abort();
        }
        cycles = uint32_t(value);
    }
    printf("RESOLVE_DELAY_CYCLES=%u; lane multiplier=1..4\n", cycles);
}

static void instrument(CUcontext ctx, CUfunction kernel) {
    std::vector<CUfunction> functions = nvbit_get_related_functions(ctx, kernel);
    functions.push_back(kernel);
    for (auto function : functions) {
        if (!instrumented.insert(function).second) continue;
        unsigned count = 0;
        for (auto instruction : nvbit_get_instrs(ctx, function)) {
            if (instruction->getMemorySpace() != InstrType::MemorySpace::GLOBAL)
                continue;
            nvbit_insert_call(instruction, "delay_memory", IPOINT_BEFORE);
            nvbit_add_call_arg_guard_pred_val(instruction);
            nvbit_add_call_arg_const_val32(instruction, cycles);
            ++count;
        }
        printf("delay instrumented %s: %u global-memory SASS sites\n",
               nvbit_get_func_name(ctx, function), count);
    }
}

void nvbit_at_cuda_event(CUcontext ctx, int is_exit, nvbit_api_cuda_t cbid,
                         const char*, void* params, CUresult*) {
    if (is_exit) return;
    if (cbid != API_CUDA_cuLaunch && cbid != API_CUDA_cuLaunchKernel_ptsz &&
        cbid != API_CUDA_cuLaunchGrid && cbid != API_CUDA_cuLaunchGridAsync &&
        cbid != API_CUDA_cuLaunchKernel && cbid != API_CUDA_cuLaunchKernelEx &&
        cbid != API_CUDA_cuLaunchKernelEx_ptsz) return;
    CUfunction kernel;
    if (cbid == API_CUDA_cuLaunchKernelEx || cbid == API_CUDA_cuLaunchKernelEx_ptsz)
        kernel = static_cast<cuLaunchKernelEx_params*>(params)->f;
    else
        kernel = static_cast<cuLaunchKernel_params*>(params)->f;
    instrument(ctx, kernel);
    nvbit_enable_instrumented(ctx, kernel, true);
}
