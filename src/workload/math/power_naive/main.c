/* Workload: Naive exponentiation with multiple test cases */
#include <stdint.h>
#define NLOOP CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_power_naive(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_power_naive(10);
    perf_start(&ctx);
    test_power_naive(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("power_naive", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
