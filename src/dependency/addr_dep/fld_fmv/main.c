/* Dependency test: FLD→FMV.X.D load address dependency */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_fld_fmv(uint64_t nloop, uint64_t *node);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    /* Self-loop node for pointer chase */
    uint64_t node[8] __attribute__((aligned(64)));
    node[0] = (uint64_t)node;

    test_fld_fmv(1000, node);
    perf_start(&ctx);
    test_fld_fmv(NLOOP, node);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("FLD->FMV addr", cycles, instret,
              (uint64_t)NLOOP * 100, 2);
    perf_close(&ctx);
    return 0;
}
