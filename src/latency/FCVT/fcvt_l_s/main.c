/* Latency test: FCVT.L.S lat */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_fcvt_l_s(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_fcvt_l_s(1000);
    perf_start(&ctx);
    test_fcvt_l_s(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("FCVT.L.S lat", cycles, instret,
              (uint64_t)NLOOP * 100, 2);
    perf_close(&ctx);
    return 0;
}
