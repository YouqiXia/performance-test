/* Throughput test: SLTIU tput */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_sltiu(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_sltiu(1000);
    perf_start(&ctx);
    test_sltiu(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("SLTIU tput", cycles, instret,
              (uint64_t)NLOOP * 100, 1);
    perf_close(&ctx);
    return 0;
}
