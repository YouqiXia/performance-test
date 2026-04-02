/* ILP test: LOAD ILP=1 — single self-loop pointer chase */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_load_ilp1(uint64_t nloop, uint64_t *n0);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    uint64_t node0[8] __attribute__((aligned(64)));
    node0[0] = (uint64_t)node0;

    test_load_ilp1(1000, node0);
    perf_start(&ctx);
    test_load_ilp1(NLOOP, node0);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("LOAD ILP=1", cycles, instret,
              (uint64_t)NLOOP * 100, 1);
    perf_close(&ctx);
    return 0;
}
