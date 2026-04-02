/* Workload: Primality test with dense rem operations */
#include <stdint.h>
#define NLOOP CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_is_prime(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_is_prime(10);
    perf_start(&ctx);
    test_is_prime(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("is_prime", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
