/* ILP test: LOAD ILP=4 — four independent self-loop pointer chases */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(400)
#include "perf_helpers.h"

extern void test_load_ilp4(uint64_t nloop, uint64_t *n0, uint64_t *n1,
                           uint64_t *n2, uint64_t *n3);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    uint64_t node0[8] __attribute__((aligned(64)));
    uint64_t node1[8] __attribute__((aligned(64)));
    uint64_t node2[8] __attribute__((aligned(64)));
    uint64_t node3[8] __attribute__((aligned(64)));
    node0[0] = (uint64_t)node0;
    node1[0] = (uint64_t)node1;
    node2[0] = (uint64_t)node2;
    node3[0] = (uint64_t)node3;

    test_load_ilp4(1000, node0, node1, node2, node3);
    perf_start(&ctx);
    test_load_ilp4(NLOOP, node0, node1, node2, node3);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("LOAD ILP=4", cycles, instret,
              (uint64_t)NLOOP * 100, 4);
    perf_close(&ctx);
    return 0;
}
