/*
 * TLB Size Measurement via Pointer Chase
 *
 * 构造：
 *   分配一块连续内存（npages × 4KB），按 4KB 分页。
 *   每页访问不同 offset 的一个 cacheline（64B）。
 *   第 i 页的 node 放在 offset = (i % NUM_SETS) × CACHELINE，
 *   使不同页的 node 散布到不同的 L1D set，避免 set conflict。
 *
 *   D-cache always hit 保证（以 L1D=32KB, 8-way, 64B line 为例）：
 *     sets = 32KB / 8 / 64B = 64 sets
 *     每个 set 最多被占 ceil(N/64) 个 way。
 *     N ≤ 64 × 8 = 512 时，每个 set ≤ 8 way → L1D 全部 hit。
 *
 *   将 N 个页按随机顺序串成 pointer chase 环。
 *   当 N > dTLB entry 数时，出现 TLB miss，latency 跳变。
 *
 * 随机化页序击败 TLB prefetcher。
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>
#include "arch_params.h"
#include "perf_helpers.h"

#define PAGE_SIZE   4096
#define CACHELINE   ARCH_CACHELINE

/* L1D set 数 = L1D_SIZE / WAYS / CACHELINE */
#define NUM_SETS        (ARCH_L1D_SIZE / ARCH_L1D_WAYS / CACHELINE)

/* 一个 4KB 页内最多能放多少个不同 cacheline offset */
#define OFFSETS_PER_PAGE  (PAGE_SIZE / CACHELINE)  /* = 64 */

/* node offset within page for page i: spread across different sets
 * 用 min(NUM_SETS, OFFSETS_PER_PAGE) 做模，确保不超出页边界 */
#define OFFSET_MOD  (NUM_SETS < OFFSETS_PER_PAGE ? NUM_SETS : OFFSETS_PER_PAGE)
#define NODE_OFFSET(i)  (((i) % OFFSET_MOD) * CACHELINE)

/* 页 i 的 node 地址（buf 为整块内存基地址） */
#define NODE_PTR(buf, i)  ((void **)((char *)(buf) + (size_t)(i) * PAGE_SIZE + NODE_OFFSET(i)))

#ifdef USE_SPIKE
#define BATCH       1024
#define MIN_BATCHES 2
#define NUM_RUNS    1
#else
#define BATCH       (100 * 1024)
#define MIN_BATCHES 20
#define NUM_RUNS    5
#endif

#ifdef USE_SPIKE
static const int NUM_PAGES[] = {
    16, 64, 128, 256, 512, 1024, 2048,
    0
};
#else
static const int NUM_PAGES[] = {
    2, 4, 6, 8, 10, 12, 14, 16,
    20, 24, 28, 32,
    40, 48, 56, 64,
    80, 96, 112, 128,
    160, 192, 224, 256,
    320, 384, 448, 512,
    640, 768, 1024,
    1536, 2048, 3072, 4096,
    5120, 6144, 8192,
    0
};
#endif

static void shuffle(int *a, int n)
{
    for (int i = n - 1; i > 0; i--) {
        int j = rand() % (i + 1);
        int t = a[i]; a[i] = a[j]; a[j] = t;
    }
}

/*
 * 构建跨页 pointer chase 环。
 * 一次 posix_memalign 分配整块内存，按页切割。
 * 返回链头指针，*buf_out = 整块内存基地址。
 */
static void **build_tlb_chain(int npages, void **buf_out)
{
    size_t total = (size_t)npages * PAGE_SIZE;
    void *buf = NULL;
    if (posix_memalign(&buf, PAGE_SIZE, total)) {
        *buf_out = NULL;
        return NULL;
    }
    memset(buf, 0, total);

    int *order = malloc(npages * sizeof(int));
    if (!order) {
        free(buf);
        *buf_out = NULL;
        return NULL;
    }
    for (int i = 0; i < npages; i++) order[i] = i;
    shuffle(order, npages);

    /* 串成环 */
    for (int i = 0; i < npages - 1; i++) {
        void **slot = NODE_PTR(buf, order[i]);
        slot[0] = (void *)NODE_PTR(buf, order[i + 1]);
    }
    {
        void **slot = NODE_PTR(buf, order[npages - 1]);
        slot[0] = (void *)NODE_PTR(buf, order[0]);
    }

    void **head = NODE_PTR(buf, order[0]);

    /* 验证链完整性：走 npages 步应回到 head */
    void **p = head;
    for (int i = 0; i < npages; i++) {
        if ((char *)p < (char *)buf || (char *)p >= (char *)buf + total) {
            fprintf(stderr, "ERROR: chain broken at step %d/%d, "
                    "ptr=%p not in [%p, %p)\n",
                    i, npages, (void *)p, buf, (char *)buf + total);
            free(order);
            free(buf);
            *buf_out = NULL;
            return NULL;
        }
        p = (void **)*p;
    }
    if (p != head) {
        fprintf(stderr, "ERROR: chain does not form a cycle "
                "(after %d steps, got %p, expected %p)\n",
                npages, (void *)p, (void *)head);
        free(order);
        free(buf);
        *buf_out = NULL;
        return NULL;
    }

    free(order);
    *buf_out = buf;
    return head;
}

static double measure_tlb(void **head, perf_ctx_t *ctx)
{
    register void **p = head;

    /* warmup */
    for (int b = 0; b < 5; b++)
        for (int i = 0; i < BATCH; i++)
            p = (void **)*p;

    uint64_t total = 0, cycles, instret;
    perf_start(ctx);
    for (int b = 0; b < MIN_BATCHES; b++) {
        for (int i = 0; i < BATCH; i++)
            p = (void **)*p;
        total += BATCH;
    }
    perf_stop(ctx, &cycles, &instret);
    __asm__ volatile("" :: "r"(p) : "memory");
    return (double)cycles / (double)total;
}

static int dbl_cmp(const void *a, const void *b)
{
    double x = *(double *)a, y = *(double *)b;
    return (x > y) - (x < y);
}

int main(void)
{
    /* 每个 offset 被 ceil(N/OFFSET_MOD) 个页共享，需 ≤ WAYS 才不 conflict */
    int l1d_safe_max = OFFSET_MOD * ARCH_L1D_WAYS;

    printf("================================================\n");
    printf("  dTLB Size Measurement (4KB pages)\n");
    printf("  Pointer chase, randomized page order\n");
    printf("  Node offset per page varies to avoid L1D set conflict\n");
    printf("  L1D: %d KB, %d-way, %d sets\n",
           ARCH_L1D_SIZE / 1024, ARCH_L1D_WAYS, NUM_SETS);
    printf("  Max pages w/o L1D conflict: %d\n", l1d_safe_max);
    printf("  Batch: %d | Runs: %d\n", BATCH, NUM_RUNS);
    printf("================================================\n\n");

    printf("%-10s  %10s\n", "Pages", "Cyc/Access");
    printf("----------  ----------\n");

    perf_ctx_t ctx = perf_init();
    srand(42);

    mkdir("logs", 0755);
    FILE *csv = fopen("logs/tlb_size.csv", "w");
    if (csv) fprintf(csv, "pages,cyc_per_access\n");

    for (int i = 0; NUM_PAGES[i] != 0; i++) {
        int npages = NUM_PAGES[i];
        double results[NUM_RUNS];

        void *buf;
        void **head = build_tlb_chain(npages, &buf);
        if (!head) {
            printf("%-10d  %s\n", npages, "(failed)");
            continue;
        }

        for (int r = 0; r < NUM_RUNS; r++)
            results[r] = measure_tlb(head, &ctx);

        free(buf);

        qsort(results, NUM_RUNS, sizeof(double), dbl_cmp);
        double median = results[NUM_RUNS / 2];

        const char *note = "";
        if (npages == l1d_safe_max)
            note = "  <-- L1D safe limit";
        else if (npages > l1d_safe_max)
            note = "  *";

        printf("%-10d  %8.2f%s\n", npages, median, note);
        fflush(stdout);

        if (csv) fprintf(csv, "%d,%.3f\n", npages, median);
    }

    if (csv) { fclose(csv); printf("\nCSV written\n"); }

    printf("\n====== 解读 ======\n");
    printf("latency 平稳区间  → 全部 TLB hit\n");
    printf("第一次跳变        → dTLB entry 数\n");
    printf("第二次跳变        → L2 TLB / sTLB entry 数\n");
    printf("\n标注 * 的行（>%d 页）可能混入 L1D set conflict miss，\n",
           l1d_safe_max);
    printf("此区间的 latency 上升可能是 TLB + D-cache miss 叠加。\n");

    perf_close(&ctx);
    return 0;
}
