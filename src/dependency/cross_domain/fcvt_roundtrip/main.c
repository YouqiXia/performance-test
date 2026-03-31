/* Dependency test: FCVT INT↔FP roundtrip */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_fcvt_roundtrip(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_fcvt_roundtrip(1000);
    perf_start(&ctx);
    test_fcvt_roundtrip(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("FCVT INT<->FP", cycles, instret,
              (uint64_t)NLOOP * 100, 2);
    perf_close(&ctx);
    return 0;
}
