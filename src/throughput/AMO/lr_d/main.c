/* Throughput test: LR.D tput */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define NLOOP  CALC_NLOOP(20)
#include "perf_helpers.h"

extern void test_lr_d(uint64_t nloop, void *buf);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t buf[64] __attribute__((aligned(64)));
    memset(buf, 0, sizeof(buf));
    {
        double one = 1.0;
        for (int i = 0; i < 64; i++)
            memcpy(&buf[i], &one, sizeof(double));
    }

    uint64_t cycles, instret;
    test_lr_d(1000, buf);
    perf_start(&ctx);
    test_lr_d(NLOOP, buf);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("LR.D tput", cycles, instret,
              (uint64_t)NLOOP * 20, 1);
    perf_close(&ctx);
    return 0;
}
