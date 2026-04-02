/* Workload: find MSB position (binary search) */
#include <stdint.h>
#define NLOOP CALC_NLOOP(30)
#include "perf_helpers.h"

extern void test_msb_binary(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_msb_binary(10);
    perf_start(&ctx);
    test_msb_binary(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("msb_binary", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
