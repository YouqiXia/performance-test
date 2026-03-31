/* Throughput test: REM tput */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(20)
#include "perf_helpers.h"

extern void test_rem(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_rem(1000);
    perf_start(&ctx);
    test_rem(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("REM tput", cycles, instret,
              (uint64_t)NLOOP * 20, 1);
    perf_close(&ctx);
    return 0;
}
