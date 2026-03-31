/* Latency test: AMOADD.W lat */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define NLOOP  CALC_NLOOP(20)
#include "perf_helpers.h"

extern void test_amoadd_w(uint64_t nloop, void *buf);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t buf[8] __attribute__((aligned(64)));
    memset(buf, 0, sizeof(buf));

    uint64_t cycles, instret;
    test_amoadd_w(1000, buf);
    perf_start(&ctx);
    test_amoadd_w(NLOOP, buf);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("AMOADD.W lat", cycles, instret,
              (uint64_t)NLOOP * 20, 1);
    perf_close(&ctx);
    return 0;
}
