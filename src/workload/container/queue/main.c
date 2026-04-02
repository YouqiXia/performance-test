/* Workload: circular queue (enqueue+dequeue with rem) */
#include <stdint.h>
#define NLOOP CALC_NLOOP(30)
#include "perf_helpers.h"

extern void test_queue(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_queue(10);
    perf_start(&ctx);
    test_queue(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("queue", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
