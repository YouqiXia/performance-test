/* ILP test: ADD ILP=1 — single self-dependent chain */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_add_ilp1(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_add_ilp1(1000);
    perf_start(&ctx);
    test_add_ilp1(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("ADD ILP=1", cycles, instret,
              (uint64_t)NLOOP * 100, 1);
    perf_close(&ctx);
    return 0;
}
