/* Workload: 8x8 matrix multiply */
#include <stdint.h>
#define NLOOP CALC_NLOOP(5000)
#include "perf_helpers.h"

extern void test_mat_multi(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_mat_multi(10);
    perf_start(&ctx);
    test_mat_multi(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("mat_multi", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
