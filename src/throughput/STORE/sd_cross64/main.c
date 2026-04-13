/* Throughput test: SD crossing 64B cacheline boundary */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define NLOOP  CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_sd_cross64(uint64_t nloop, void *buf);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    /* Need at least 260 bytes (offset 252 + 8); use 512B aligned to 64B */
    uint8_t raw[512] __attribute__((aligned(64)));
    memset(raw, 0, sizeof(raw));

    uint64_t cycles, instret;
    test_sd_cross64(1000, raw);
    perf_start(&ctx);
    test_sd_cross64(NLOOP, raw);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("SD cross64 tput", cycles, instret,
              (uint64_t)NLOOP * 100, 1);
    perf_close(&ctx);
    return 0;
}
