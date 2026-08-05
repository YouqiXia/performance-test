/* Throughput test: BLT tput */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_blt(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_blt(1000);
    perf_start(&ctx);
    test_blt(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("BLT tput", cycles, instret,
              (uint64_t)NLOOP * 200, 1);
    perf_close(&ctx);
    return 0;
}
