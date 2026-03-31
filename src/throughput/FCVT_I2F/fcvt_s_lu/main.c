/* Throughput test: FCVT.S.LU tput */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_fcvt_s_lu(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_fcvt_s_lu(1000);
    perf_start(&ctx);
    test_fcvt_s_lu(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("FCVT.S.LU tput", cycles, instret,
              (uint64_t)NLOOP * 100, 1);
    perf_close(&ctx);
    return 0;
}
