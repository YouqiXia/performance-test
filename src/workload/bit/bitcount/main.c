/* Workload: naive popcount (64-bit shift+count) */
#include <stdint.h>
#define NLOOP CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_bitcount(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_bitcount(10);
    perf_start(&ctx);
    test_bitcount(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("bitcount", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
