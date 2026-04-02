/* Workload: Dijkstra shortest path on 5-vertex weighted graph */
#include <stdint.h>
#define NLOOP CALC_NLOOP(1000)
#include "perf_helpers.h"

extern void test_dijkstra(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_dijkstra(10);
    perf_start(&ctx);
    test_dijkstra(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("dijkstra", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
