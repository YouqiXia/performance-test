/* Throughput test: AMOMAXU.W tput */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#define NLOOP  CALC_NLOOP(20)
#include "perf_helpers.h"

extern void test_amomaxu_w(uint64_t nloop, void *buf);

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
    test_amomaxu_w(1000, buf);
    perf_start(&ctx);
    test_amomaxu_w(NLOOP, buf);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("AMOMAXU.W tput", cycles, instret,
              (uint64_t)NLOOP * 20, 1);
    perf_close(&ctx);
    return 0;
}
