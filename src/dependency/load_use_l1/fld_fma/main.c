/* Dependency test: FLD→FMA→FSD (L1) store-forwarding chain */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#define NLOOP  CALC_NLOOP(300)
#include "perf_helpers.h"

extern void test_fld_fma(uint64_t nloop, uint64_t *buf);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    /* FP data buffer (L1 resident) */
    uint64_t fp_buf[8] __attribute__((aligned(64)));
    double one = 1.0;
    memcpy(&fp_buf[0], &one, sizeof(double));

    /* Init FP regs: ft1=1.0, ft2=0.0 */
    double v1 = 1.0, v2 = 0.0;
    asm volatile("fmv.d.x ft1, %0" : : "r"(*(uint64_t*)&v1) : "ft1");
    asm volatile("fmv.d.x ft2, %0" : : "r"(*(uint64_t*)&v2) : "ft2");

    test_fld_fma(1000, fp_buf);
    perf_start(&ctx);
    test_fld_fma(NLOOP, fp_buf);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("FLD->FMA->FSD L1", cycles, instret,
              (uint64_t)NLOOP * 100, 3);
    perf_close(&ctx);
    return 0;
}
