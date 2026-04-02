/* ILP test: LOAD ILP=2 — two independent self-loop pointer chases */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_load_ilp2(uint64_t nloop, uint64_t *n0, uint64_t *n1);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    uint64_t node0[8] __attribute__((aligned(64)));
    uint64_t node1[8] __attribute__((aligned(64)));
    node0[0] = (uint64_t)node0;
    node1[0] = (uint64_t)node1;

    test_load_ilp2(1000, node0, node1);
    perf_start(&ctx);
    test_load_ilp2(NLOOP, node0, node1);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("LOAD ILP=2", cycles, instret,
              (uint64_t)NLOOP * 100, 2);
    perf_close(&ctx);
    return 0;
}
