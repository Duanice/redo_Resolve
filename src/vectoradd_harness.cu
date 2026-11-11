// The unmodified NVBit v1.8.1 tutorial kernel is included at build time.
#define main nvbit_tutorial_main
#include "vectoradd.cu"
#undef main

#include <cstdint>
#include <cstring>
#include <vector>

#define CHECK(call)                                                          \
    do {                                                                     \
        cudaError_t err = (call);                                           \
        if (err != cudaSuccess) {                                           \
            fprintf(stderr, "%s:%d: %s\n", __FILE__, __LINE__,           \
                    cudaGetErrorString(err));                               \
            return 1;                                                        \
        }                                                                    \
    } while (0)

__global__ void vecAddReduced(const double* a, const double* b, double* c,
                              int n) {
    if (blockIdx.x == 0 && threadIdx.x == 0)
        for (int i = 0; i < n; ++i) c[i] = a[i] + b[i];
}

static uint64_t fnv1a(const double* values, int n) {
    const auto* p = reinterpret_cast<const unsigned char*>(values);
    uint64_t h = 14695981039346656037ULL;
    for (size_t i = 0; i < size_t(n) * sizeof(double); ++i) {
        h ^= p[i];
        h *= 1099511628211ULL;
    }
    return h;
}

int main(int argc, char** argv) {
    const int n = argc > 1 ? atoi(argv[1]) : 256;
    if (n < 1 || n > 1024) {
        fputs("n must be between 1 and 1024\n", stderr);
        return 2;
    }
    constexpr int runs = 4;
    const size_t bytes = size_t(n) * sizeof(double);
    std::vector<double> a(n), b(n), original(n), reduced(n), first(n);
    double *d_a, *d_b, *d_original, *d_reduced;
    CHECK(cudaMalloc(&d_a, bytes));
    CHECK(cudaMalloc(&d_b, bytes));
    CHECK(cudaMalloc(&d_original, bytes));
    CHECK(cudaMalloc(&d_reduced, bytes));

    for (int input_case = 0; input_case < 3; ++input_case) {
        for (int i = 0; i < n; ++i) {
            if (input_case == 0) {
                a[i] = double(i);
                b[i] = double(2 * i);
            } else if (input_case == 1) {
                a[i] = i & 1 ? 1e20 : 1e-20;
                b[i] = -a[i];
            } else {
                a[i] = sin(double(i)) * sin(double(i));
                b[i] = cos(double(i)) * cos(double(i));
            }
        }
        CHECK(cudaMemcpy(d_a, a.data(), bytes, cudaMemcpyHostToDevice));
        CHECK(cudaMemcpy(d_b, b.data(), bytes, cudaMemcpyHostToDevice));
        for (int run = 0; run < runs; ++run) {
            CHECK(cudaMemset(d_original, 0xa5, bytes));
            CHECK(cudaMemset(d_reduced, 0xa5, bytes));
            vecAdd<<<1, 1024>>>(d_a, d_b, d_original, n);
            CHECK(cudaGetLastError());
            vecAddReduced<<<1, 1>>>(d_a, d_b, d_reduced, n);
            CHECK(cudaGetLastError());
            CHECK(cudaDeviceSynchronize());
            CHECK(cudaMemcpy(original.data(), d_original, bytes,
                             cudaMemcpyDeviceToHost));
            CHECK(cudaMemcpy(reduced.data(), d_reduced, bytes,
                             cudaMemcpyDeviceToHost));
            if (memcmp(original.data(), reduced.data(), bytes) != 0) {
                fprintf(stderr, "case %d run %d: original/reduced differ\n",
                        input_case, run);
                return 1;
            }
            if (run && memcmp(original.data(), first.data(), bytes) != 0) {
                fprintf(stderr, "case %d run %d: nondeterministic\n",
                        input_case, run);
                return 1;
            }
            if (!run) first = original;
            for (int i = 0; i < n; ++i) {
                const double expected = a[i] + b[i];
                if (memcmp(&expected, &original[i], sizeof(double)) != 0) {
                    fprintf(stderr, "case %d run %d index %d: wrong value\n",
                            input_case, run, i);
                    return 1;
                }
            }
        }
        printf("case=%d n=%d runs=%d original_reduced=PASS repeat=PASS "
               "cpu=PASS fnv1a=%016llx\n", input_case, n, runs,
               (unsigned long long)fnv1a(original.data(), n));
    }

    CHECK(cudaFree(d_a));
    CHECK(cudaFree(d_b));
    CHECK(cudaFree(d_original));
    CHECK(cudaFree(d_reduced));
    return 0;
}
