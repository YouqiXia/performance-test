/* Latency test: LD lat */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_ld(uint64_t nloop, void *node);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t node[8] __attribute__((aligned(64)));
    node[0] = (uint64_t)&node[0];

    uint64_t cycles, instret;
    test_ld(1000, node);
    perf_start(&ctx);
    test_ld(NLOOP, node);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("LD lat", cycles, instret,
              (uint64_t)NLOOP * 100, 1);
    perf_close(&ctx);
    return 0;
}
