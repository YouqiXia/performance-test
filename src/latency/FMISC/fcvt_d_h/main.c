/* Latency test: FCVT.D.H lat */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_fcvt_d_h(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_fcvt_d_h(1000);
    perf_start(&ctx);
    test_fcvt_d_h(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("FCVT.D.H lat", cycles, instret,
              (uint64_t)NLOOP * 50, 2);
    perf_close(&ctx);
    return 0;
}
