/* ILP test: ADD ILP=2 — two independent self-dependent chains */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_add_ilp2(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_add_ilp2(1000);
    perf_start(&ctx);
    test_add_ilp2(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("ADD ILP=2", cycles, instret,
              (uint64_t)NLOOP * 100, 2);
    perf_close(&ctx);
    return 0;
}
