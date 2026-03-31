/* Dependency test: FDIV↔FMUL forwarding chain */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define NLOOP  CALC_NLOOP(40)
#include "perf_helpers.h"

extern void test_fdiv_fmul(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    /* Init FP regs: ft0=1.0, ft1=1.0, ft2=1.0 */
    double v0 = 1.0, v1 = 1.0, v2 = 1.0;
    asm volatile(
        "fmv.d.x ft0, %0\n\t"
        "fmv.d.x ft1, %1\n\t"
        "fmv.d.x ft2, %2\n\t"
        : : "r"(*(uint64_t*)&v0), "r"(*(uint64_t*)&v1), "r"(*(uint64_t*)&v2)
        : "ft0", "ft1", "ft2"
    );

    test_fdiv_fmul(1000);
    perf_start(&ctx);
    test_fdiv_fmul(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("FDIV<->FMUL fwd", cycles, instret,
              (uint64_t)NLOOP * 20, 2);
    perf_close(&ctx);
    return 0;
}
