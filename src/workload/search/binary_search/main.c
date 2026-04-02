/* Workload: binary search */
#include <stdint.h>
#define NLOOP CALC_NLOOP(20)
#include "perf_helpers.h"

extern void test_binary_search(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_binary_search(10);
    perf_start(&ctx);
    test_binary_search(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("binary_search", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
