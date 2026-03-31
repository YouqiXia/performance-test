/* Dependency test: FCLASS↔FCVT cross-domain chain */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_fclass_fcvt(uint64_t nloop);

int main(void)
{
    /* Initialize ft0 to 1.0 so fclass outputs a valid classification bitmask */
    double v0 = 1.0;
    asm volatile("fmv.d.x ft0, %0" : : "r"(*(uint64_t*)&v0) : "ft0");

    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_fclass_fcvt(1000);
    perf_start(&ctx);
    test_fclass_fcvt(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("FCLASS<->FCVT", cycles, instret,
              (uint64_t)NLOOP * 100, 2);
    perf_close(&ctx);
    return 0;
}
