/* Workload: find MSB position (linear scan) */
#include <stdint.h>
#define NLOOP CALC_NLOOP(50)
#include "perf_helpers.h"

extern void test_find_msb(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_find_msb(10);
    perf_start(&ctx);
    test_find_msb(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("find_msb", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
