/* Workload: 4x unrolled dot product of 64-element arrays */
#include <stdint.h>
#define NLOOP CALC_NLOOP(2000)
#include "perf_helpers.h"

extern void test_dot_product(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_dot_product(10);
    perf_start(&ctx);
    test_dot_product(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("dot_product", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
