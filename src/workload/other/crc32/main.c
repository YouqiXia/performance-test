/* Workload: CRC32 table lookup */
#include <stdint.h>
#define NLOOP CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_crc32(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_crc32(10);
    perf_start(&ctx);
    test_crc32(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("crc32", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
