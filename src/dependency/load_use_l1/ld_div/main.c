/* Dependency test: LD↔DIV (L1) forwarding chain */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#define NLOOP  CALC_NLOOP(40)
#include "perf_helpers.h"

extern void test_ld_div(uint64_t nloop, uint64_t *node);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    /* Self-loop node for L1 pointer chase */
    uint64_t node_storage[8] __attribute__((aligned(64)));
    uint64_t *node = &node_storage[0];
    node[0] = (uint64_t)node;

    test_ld_div(1000, node);
    perf_start(&ctx);
    test_ld_div(NLOOP, node);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("LD<->DIV L1", cycles, instret,
              (uint64_t)NLOOP * 20, 2);
    perf_close(&ctx);
    return 0;
}
