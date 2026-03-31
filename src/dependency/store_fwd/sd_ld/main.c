/* Dependency test: SD↔LD INT store forwarding */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_sd_ld(uint64_t nloop, uint64_t *buf);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    uint64_t buf[8] __attribute__((aligned(64)));
    buf[0] = 42;

    test_sd_ld(1000, buf);
    perf_start(&ctx);
    test_sd_ld(NLOOP, buf);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("SD<->LD fwd", cycles, instret,
              (uint64_t)NLOOP * 100, 2);
    perf_close(&ctx);
    return 0;
}
