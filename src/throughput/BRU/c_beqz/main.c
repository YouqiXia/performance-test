/* Throughput test: C.BEQZ tput */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_c_beqz(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_c_beqz(1000);
    perf_start(&ctx);
    test_c_beqz(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("C.BEQZ tput", cycles, instret,
              (uint64_t)NLOOP * 100, 1);
    perf_close(&ctx);
    return 0;
}
