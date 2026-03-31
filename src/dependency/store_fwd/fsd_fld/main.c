/* Dependency test: FSD↔FLD FP store forwarding */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define NLOOP  CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_fsd_fld(uint64_t nloop, uint64_t *buf);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    /* FP data buffer (L1 resident) */
    uint64_t buf[8] __attribute__((aligned(64)));
    double one = 1.0;
    memcpy(&buf[0], &one, sizeof(double));

    /* Init ft0 by loading from buf */
    asm volatile("fld ft0, 0(%0)" : : "r"(buf) : "ft0");

    test_fsd_fld(1000, buf);
    perf_start(&ctx);
    test_fsd_fld(NLOOP, buf);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("FSD<->FLD fwd", cycles, instret,
              (uint64_t)NLOOP * 100, 2);
    perf_close(&ctx);
    return 0;
}
