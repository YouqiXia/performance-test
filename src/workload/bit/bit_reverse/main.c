/* Workload: 32-bit reversal */
#include <stdint.h>
#define NLOOP CALC_NLOOP(160)
#include "perf_helpers.h"

extern void test_bit_reverse(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_bit_reverse(10);
    perf_start(&ctx);
    test_bit_reverse(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("bit_reverse", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
