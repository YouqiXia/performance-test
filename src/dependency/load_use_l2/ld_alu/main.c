/* Dependency test: LD↔ALU (L2) forwarding chain */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "arch_params.h"
#define NLOOP  CALC_NLOOP(200)
#include "perf_helpers.h"

#define WORKING_SET  ARCH_L2_WORKING_SET
#define CACHELINE    ARCH_CACHELINE
#define STRIDE       (CACHELINE / (int)sizeof(void *))

extern void test_ld_alu(uint64_t nloop, void *head);

static void shuffle(int *a, int n) {
    for (int i = n - 1; i > 0; i--) {
        int j = rand() % (i + 1);
        int t = a[i]; a[i] = a[j]; a[j] = t;
    }
}

static void **build_random_chain(size_t bytes, int *out_nodes) {
    int n = bytes / CACHELINE;
    if (n < 2) { *out_nodes = 0; return NULL; }
    void **buf = NULL;
    if (posix_memalign((void **)&buf, 4096, bytes)) return NULL;
    memset(buf, 0, bytes);
    int *order = malloc(n * sizeof(int));
    if (!order) { free(buf); *out_nodes = 0; return NULL; }
    for (int i = 0; i < n; i++) order[i] = i;
    shuffle(order, n);
    for (int i = 0; i < n - 1; i++)
        buf[order[i] * STRIDE] = &buf[order[i + 1] * STRIDE];
    buf[order[n - 1] * STRIDE] = &buf[order[0] * STRIDE];
    free(order);
    *out_nodes = n;
    return buf;
}

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    srand(42);

    int nnodes;
    void **chain = build_random_chain(WORKING_SET, &nnodes);
    if (!chain) { fprintf(stderr, "alloc failed\n"); return 1; }

    test_ld_alu(1000, chain);
    perf_start(&ctx);
    test_ld_alu(NLOOP, chain);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("LD<->ALU L2", cycles, instret,
              (uint64_t)NLOOP * 100, 2);

    free(chain);
    perf_close(&ctx);
    return 0;
}
