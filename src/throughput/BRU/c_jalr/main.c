/* Throughput test: C.JALR tput */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(99)
#include "perf_helpers.h"

extern void test_c_jalr(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_c_jalr(1000);
    perf_start(&ctx);
    test_c_jalr(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("C.JALR tput", cycles, instret,
              (uint64_t)NLOOP * 99, 1);
    perf_close(&ctx);
    return 0;
}
