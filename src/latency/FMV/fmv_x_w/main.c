/* Latency test: FMV.X.W lat */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_fmv_x_w(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_fmv_x_w(1000);
    perf_start(&ctx);
    test_fmv_x_w(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("FMV.X.W lat", cycles, instret,
              (uint64_t)NLOOP * 100, 2);
    perf_close(&ctx);
    return 0;
}
