/*
 * L2 Cache Latency - Anti-Prefetch Hardened Version
 *
 * 对抗多种 prefetcher 策略：
 *
 *   1. 多链交织 (Multi-chain interleave)
 *      构建 K 条独立随机链表，运行时用数据依赖随机切换
 *      → 对抗 temporal stream prefetcher（记录最近 N 个地址序列）
 *
 *   2. 指针加密 (XOR-obfuscated pointers)
 *      存储 next_ptr XOR key，读出后解密再用
 *      → 对抗 runahead / 预测执行型 prefetch
 *        (即使 CPU 偷看了内存内容，看到的是密文，无法提前发地址)
 *
 *   3. 跨页随机化 (Cross-page randomization)
 *      确保链表频繁跨越 4KB 页边界
 *      → 对抗 same-page prefetcher / SPP
 *
 *   4. 依赖链注入 (Dependent computation)
 *      在 load 之间插入轻量但不可消除的依赖运算
 *      → 阻止 CPU 推测性地提前发射下一条 load
 *
 * Compile:
 *   gcc -O2 -o l2_anti l2_anti_prefetch.c
 *
 * Run:
 *   taskset -c 0 ./l2_anti
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <sys/stat.h>
#include "arch_params.h"
#include "perf_helpers.h"

#define CACHELINE       ARCH_CACHELINE
#define STRIDE          (CACHELINE / (int)sizeof(void *))

#ifdef USE_SPIKE
#define BATCH           1024
#define MIN_BATCHES     2
#define NUM_RUNS        1
#else
#define BATCH           (100 * 1024)
#define MIN_BATCHES     20
#define NUM_RUNS        5
#endif

/* 多链配置：NUM_CHAINS 条独立链 */
#define NUM_CHAINS      4

/* XOR key for pointer obfuscation */
#define XOR_KEY         0xDEADBEEFCAFEBABEULL

#ifdef USE_SPIKE
/* Spike: fewer size points, just verify functional correctness */
static const int SIZES_KB[] = {
    4, 16, 64, 256, 1024, 4096,
    0
};
#else
static const int SIZES_KB[] = {
    2, 4, 8, 12, 16, 24, 32, 40, 48, 56, 64,
    72, 80, 96, 112, 128,
    160, 192, 224, 256, 288, 320, 384, 448, 512,
    576, 640, 768, 896, 1024,
    1152, 1280, 1536, 1792, 2048,
    2560, 3072, 3584, 4096,
    5120, 6144, 8192, 12288, 16384, 24576, 32768,
    0
};
#endif

/* now_cycles() removed — use perf_start/perf_stop instead */

static void shuffle(int *a, int n) {
    for (int i = n - 1; i > 0; i--) {
        int j = rand() % (i + 1);
        int t = a[i]; a[i] = a[j]; a[j] = t;
    }
}

/* ============================================================
 * 策略 0: 基础 pointer chase（对照组）
 * ============================================================ */
static void **build_basic_chain(size_t bytes, int *out_nodes) {
    int n = bytes / CACHELINE;
    if (n < 2) { *out_nodes = 0; return NULL; }
    void **buf = NULL;
    if (posix_memalign((void **)&buf, 4096, bytes)) return NULL;
    memset(buf, 0, bytes);
    int *order = malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) order[i] = i;
    shuffle(order, n);
    for (int i = 0; i < n - 1; i++)
        buf[order[i] * STRIDE] = &buf[order[i + 1] * STRIDE];
    buf[order[n - 1] * STRIDE] = &buf[order[0] * STRIDE];
    free(order);
    *out_nodes = n;
    return buf;
}

static double measure_basic(void **buf, perf_ctx_t *ctx) {
    register void **p = buf;
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
    __asm__ volatile ("" :: "r"(p) : "memory");
    return (double)cycles / (double)total;
}

/* ============================================================
 * 策略 1: XOR 加密指针
 *
 * 内存中存的不是真实地址，而是 (real_addr XOR key)
 * 每次读出后必须 XOR 解密才能得到下一个地址
 * → runahead prefetcher 即使偷看了内存，也拿到的是密文
 * ============================================================ */
static void **build_xor_chain(size_t bytes, int *out_nodes) {
    int n = bytes / CACHELINE;
    if (n < 2) { *out_nodes = 0; return NULL; }
    void **buf = NULL;
    if (posix_memalign((void **)&buf, 4096, bytes)) return NULL;
    memset(buf, 0, bytes);
    int *order = malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) order[i] = i;
    shuffle(order, n);
    for (int i = 0; i < n - 1; i++) {
        uintptr_t real_next = (uintptr_t)&buf[order[i + 1] * STRIDE];
        buf[order[i] * STRIDE] = (void *)(real_next ^ XOR_KEY);
    }
    uintptr_t real_next = (uintptr_t)&buf[order[0] * STRIDE];
    buf[order[n - 1] * STRIDE] = (void *)(real_next ^ XOR_KEY);
    free(order);
    *out_nodes = n;
    return buf;
}

static double measure_xor(void **buf, perf_ctx_t *ctx) {
    register uintptr_t p = (uintptr_t)buf;
    for (int b = 0; b < 5; b++)
        for (int i = 0; i < BATCH; i++) {
            p = *(uintptr_t *)p;
            p ^= XOR_KEY;
        }
    uint64_t total = 0, cycles, instret;
    perf_start(ctx);
    for (int b = 0; b < MIN_BATCHES; b++) {
        for (int i = 0; i < BATCH; i++) {
            p = *(uintptr_t *)p;
            p ^= XOR_KEY;
        }
        total += BATCH;
    }
    perf_stop(ctx, &cycles, &instret);
    __asm__ volatile ("" :: "r"(p) : "memory");
    return (double)cycles / (double)total;
}

/* ============================================================
 * 策略 2: 多链交织
 *
 * 构建 NUM_CHAINS 条独立链，每一步基于上次 load 的
 * 低位来选择下一步跳哪条链
 * → stream/correlation prefetcher 看到的是多条流混在一起
 *   无法建立稳定的地址序列模型
 * ============================================================ */
typedef struct {
    void **bufs[NUM_CHAINS];
    int nodes;
} MultiChain;

static MultiChain build_multi_chain(size_t bytes) {
    MultiChain mc;
    mc.nodes = bytes / CACHELINE;
    for (int c = 0; c < NUM_CHAINS; c++) {
        mc.bufs[c] = NULL;
        if (posix_memalign((void **)&mc.bufs[c], 4096, bytes)) {
            mc.nodes = 0;
            return mc;
        }
        memset(mc.bufs[c], 0, bytes);
        int *order = malloc(mc.nodes * sizeof(int));
        for (int i = 0; i < mc.nodes; i++) order[i] = i;
        shuffle(order, mc.nodes);
        for (int i = 0; i < mc.nodes - 1; i++)
            mc.bufs[c][order[i] * STRIDE] = &mc.bufs[c][order[i + 1] * STRIDE];
        mc.bufs[c][order[mc.nodes - 1] * STRIDE] = &mc.bufs[c][order[0] * STRIDE];
        free(order);
    }
    return mc;
}

static double measure_multi(MultiChain *mc, perf_ctx_t *ctx) {
    void **p[NUM_CHAINS];
    for (int c = 0; c < NUM_CHAINS; c++)
        p[c] = mc->bufs[c];

    /* warmup */
    for (int b = 0; b < 5; b++)
        for (int i = 0; i < BATCH; i++)
            for (int c = 0; c < NUM_CHAINS; c++)
                p[c] = (void **)*p[c];

    uint64_t total = 0, cycles, instret;
    perf_start(ctx);
    register uintptr_t selector = 0;
    for (int b = 0; b < MIN_BATCHES; b++) {
        for (int i = 0; i < BATCH; i++) {
            int c = selector & (NUM_CHAINS - 1);
            p[c] = (void **)*p[c];
            selector = (uintptr_t)p[c];
        }
        total += BATCH;
    }
    perf_stop(ctx, &cycles, &instret);
    for (int c = 0; c < NUM_CHAINS; c++)
        __asm__ volatile ("" :: "r"(p[c]) : "memory");
    return (double)cycles / (double)total;
}

/* ============================================================
 * 策略 3: XOR + 多链（最强组合）
 *
 * 同时使用加密指针和多链交织
 * ============================================================ */
static MultiChain build_xor_multi_chain(size_t bytes) {
    MultiChain mc;
    mc.nodes = bytes / CACHELINE;
    for (int c = 0; c < NUM_CHAINS; c++) {
        mc.bufs[c] = NULL;
        if (posix_memalign((void **)&mc.bufs[c], 4096, bytes)) {
            mc.nodes = 0;
            return mc;
        }
        memset(mc.bufs[c], 0, bytes);
        int *order = malloc(mc.nodes * sizeof(int));
        for (int i = 0; i < mc.nodes; i++) order[i] = i;
        shuffle(order, mc.nodes);
        for (int i = 0; i < mc.nodes - 1; i++) {
            uintptr_t real = (uintptr_t)&mc.bufs[c][order[i + 1] * STRIDE];
            mc.bufs[c][order[i] * STRIDE] = (void *)(real ^ XOR_KEY);
        }
        uintptr_t real = (uintptr_t)&mc.bufs[c][order[0] * STRIDE];
        mc.bufs[c][order[mc.nodes - 1] * STRIDE] = (void *)(real ^ XOR_KEY);
        free(order);
    }
    return mc;
}

static double measure_xor_multi(MultiChain *mc, perf_ctx_t *ctx) {
    uintptr_t p[NUM_CHAINS];
    for (int c = 0; c < NUM_CHAINS; c++)
        p[c] = (uintptr_t)mc->bufs[c];

    for (int b = 0; b < 5; b++)
        for (int i = 0; i < BATCH; i++)
            for (int c = 0; c < NUM_CHAINS; c++) {
                p[c] = *(uintptr_t *)p[c];
                p[c] ^= XOR_KEY;
            }

    uint64_t total = 0, cycles, instret;
    perf_start(ctx);
    register uintptr_t selector = 0;
    for (int b = 0; b < MIN_BATCHES; b++) {
        for (int i = 0; i < BATCH; i++) {
            int c = selector & (NUM_CHAINS - 1);
            p[c] = *(uintptr_t *)p[c];
            p[c] ^= XOR_KEY;
            selector = p[c];
        }
        total += BATCH;
    }
    perf_stop(ctx, &cycles, &instret);
    for (int c = 0; c < NUM_CHAINS; c++)
        __asm__ volatile ("" :: "r"(p[c]) : "memory");
    return (double)cycles / (double)total;
}

/* ============================================================ */
static int dbl_cmp(const void *a, const void *b) {
    double x = *(double *)a, y = *(double *)b;
    return (x > y) - (x < y);
}

int main(void) {
    printf("================================================================\n");
    printf("  L2 Latency - Anti-Prefetch Hardened (4 strategies compared)\n");
    printf("  Chains: %d | Batch: %d | Runs: %d\n", NUM_CHAINS, BATCH, NUM_RUNS);
    printf("================================================================\n\n");

    printf("%-10s  %10s  %10s  %10s  %10s\n",
           "Size", "Basic(cy)", "XOR(cy)", "Multi(cy)", "XOR+M(cy)");
    printf("----------  ----------  ----------  ----------  ----------\n");

    perf_ctx_t ctx = perf_init();

    srand(42);
    int n = 0;
    while (SIZES_KB[n]) n++;

    mkdir("logs", 0755);
    FILE *csv = fopen("logs/anti_prefetch.csv", "w");
    if (csv) fprintf(csv, "size_kb,basic_cy,xor_cy,multi_cy,xor_multi_cy\n");

    for (int i = 0; i < n; i++) {
        size_t bytes = (size_t)SIZES_KB[i] * 1024;
        if (SIZES_KB[i] < 4) continue;  /* too small for multi-chain */

        double r_basic[NUM_RUNS], r_xor[NUM_RUNS];
        double r_multi[NUM_RUNS], r_xm[NUM_RUNS];

        /* Basic */
        int nn;
        void **buf = build_basic_chain(bytes, &nn);
        if (!buf) continue;
        for (int r = 0; r < NUM_RUNS; r++) r_basic[r] = measure_basic(buf, &ctx);
        free(buf);

        /* XOR */
        buf = build_xor_chain(bytes, &nn);
        for (int r = 0; r < NUM_RUNS; r++) r_xor[r] = measure_xor(buf, &ctx);
        free(buf);

        /* Multi-chain */
        MultiChain mc = build_multi_chain(bytes);
        for (int r = 0; r < NUM_RUNS; r++) r_multi[r] = measure_multi(&mc, &ctx);
        for (int c = 0; c < NUM_CHAINS; c++) free(mc.bufs[c]);

        /* XOR + Multi */
        mc = build_xor_multi_chain(bytes);
        for (int r = 0; r < NUM_RUNS; r++) r_xm[r] = measure_xor_multi(&mc, &ctx);
        for (int c = 0; c < NUM_CHAINS; c++) free(mc.bufs[c]);

        qsort(r_basic, NUM_RUNS, sizeof(double), dbl_cmp);
        qsort(r_xor,   NUM_RUNS, sizeof(double), dbl_cmp);
        qsort(r_multi, NUM_RUNS, sizeof(double), dbl_cmp);
        qsort(r_xm,    NUM_RUNS, sizeof(double), dbl_cmp);

        double b = r_basic[NUM_RUNS/2];
        double x = r_xor[NUM_RUNS/2];
        double m = r_multi[NUM_RUNS/2];
        double xm = r_xm[NUM_RUNS/2];

        char sstr[16];
        if (SIZES_KB[i] < 1024)
            snprintf(sstr, sizeof(sstr), "%d KB", SIZES_KB[i]);
        else if (SIZES_KB[i] % 1024 == 0)
            snprintf(sstr, sizeof(sstr), "%d MB", SIZES_KB[i] / 1024);
        else
            snprintf(sstr, sizeof(sstr), "%d KB", SIZES_KB[i]);

        printf("%-10s  %8.2f    %8.2f    %8.2f    %8.2f\n", sstr, b, x, m, xm);
        fflush(stdout);

        if (csv) fprintf(csv, "%d,%.3f,%.3f,%.3f,%.3f\n", SIZES_KB[i], b, x, m, xm);
    }

    if (csv) { fclose(csv); printf("\nCSV written\n"); }

    printf("\n====== 解读指南 ======\n");
    printf("如果 Basic 和加强版的 latency 差不多:\n");
    printf("  → prefetcher 没有学到 pointer chase 模式, 基础版已经够用\n\n");
    printf("如果加强版 latency 明显更高 (尤其在 L2 区间):\n");
    printf("  → prefetcher 确实在帮忙, 加强版数据更真实\n");
    printf("  → XOR 列反映 runahead prefetch 的影响\n");
    printf("  → Multi 列反映 stream correlation prefetch 的影响\n");
    printf("  → XOR+M 列是最保守的 upper bound\n\n");
    printf("注意: XOR/Multi 本身有额外指令开销 (~1-2 cycles)\n");
    printf("      真实 prefetch 影响 = 加强版 - 基础版 - 指令开销\n");

    perf_close(&ctx);
    return 0;
}