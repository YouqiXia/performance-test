/*
 * Speculative Wakeup Replay Penalty Test
 *
 * 利用 L1 set conflict 制造 "surprise" L1 miss，观测 replay penalty。
 *
 * DCache geometry from arch profile (see arch/*.h)
 * 同 set 不同 way 的地址间隔 = ARCH_L1D_SET_STRIDE
 *
 * 构造 5 个地址映射到同一个 cache set：
 *   addr[i] = base + i * 16KB   (i = 0..4)
 *
 * Test A: 访问 addr[0..3]（4 路全 hit）
 * Test B: 访问 addr[0..3] → addr[4]（evict addr[0]）→ addr[0]（surprise miss!）
 * Test C: 和 B 相同模式但重复跑（scheduler 可学习 miss 模式）
 *
 * 判读：
 *   Test B > Test C → surprise miss 有额外 replay penalty
 *   Test B ≈ Test C → scheduler 不做投机唤醒（或没有 miss predictor）
 *   (Test B miss处 - Test A hit处) → L1 miss penalty（含可能的 replay）
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "arch_params.h"
#define NLOOP  CALC_NLOOP(150)   /* .rept=25, max 6 insn/iter */
#include "perf_helpers.h"

extern void test_replay_l1_hit(uint64_t nloop, uint64_t **addrs);
extern void test_replay_surprise_miss(uint64_t nloop, uint64_t **addrs);
extern void test_replay_always_miss(uint64_t nloop, uint64_t **addrs);

#define REPT    25

/* 每次 .rept 的 ld+add 对数 */
#define PAIRS_A  4         /* Test A: 4 pairs per .rept */
#define PAIRS_BC 6         /* Test B/C: 6 pairs per .rept */

/*
 * 分配 5 个地址映射到同一个 cache set。
 * L1 = 64KB, 4-way → set interval = 64KB/4 = 16KB
 * 用一块连续 80KB buffer，取 base, base+16KB, base+32KB, base+48KB, base+64KB
 * 需要 base 对齐到 cacheline 且落在同一 set。
 */
#define SET_INTERVAL ARCH_L1D_SET_STRIDE

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    /* 分配 80KB+ buffer（5 * 16KB），对齐到 page */
    size_t buf_size = 5 * SET_INTERVAL + 64;
    uint8_t *buf = NULL;
    if (posix_memalign((void **)&buf, 4096, buf_size)) {
        perror("posix_memalign");
        return 1;
    }
    memset(buf, 0, buf_size);

    /* 5 个地址映射到同一 set */
    uint64_t *addrs[5];
    for (int i = 0; i < 5; i++) {
        addrs[i] = (uint64_t *)(buf + i * SET_INTERVAL);
        /* 写入一个非零值，确保 cache line 被拉入 */
        *addrs[i] = 0xDEAD0000 + i;
    }

    /* 预热：把前 4 个地址拉入 L1 */
    for (int w = 0; w < 1000; w++) {
        for (int i = 0; i < 4; i++) {
            volatile uint64_t x = *addrs[i];
            (void)x;
        }
    }

    printf("=== Speculative Wakeup Replay Penalty ===\n");
    printf("L1=%uKB %u-way, set interval=%uKB [%s]\n", ARCH_L1D_SIZE/1024, ARCH_L1D_WAYS, ARCH_L1D_SET_STRIDE/1024, ARCH_NAME);
    printf("addrs: ");
    for (int i = 0; i < 5; i++)
        printf("[%d]=%p ", i, (void *)addrs[i]);
    printf("\n\n");

    uint64_t total_a  = (uint64_t)NLOOP * REPT * PAIRS_A;
    uint64_t total_bc = (uint64_t)NLOOP * REPT * PAIRS_BC;

    /* Test A: 全部 L1 hit */
    test_replay_l1_hit(1000, addrs);  /* warmup */
    perf_start(&ctx);
    test_replay_l1_hit(NLOOP, addrs);
    perf_stop(&ctx, &cycles, &instret);
    double a_cpp = (double)cycles / total_a;  /* cycles per ld+add pair */
    perf_print("A: all L1 hit (4 addr)", cycles, instret, total_a, 2);

    /* Test B: surprise miss */
    /* 先重新预热前 4 个到 L1 */
    for (int w = 0; w < 1000; w++)
        for (int i = 0; i < 4; i++) { volatile uint64_t x = *addrs[i]; (void)x; }

    test_replay_surprise_miss(1000, addrs);  /* warmup */
    perf_start(&ctx);
    test_replay_surprise_miss(NLOOP, addrs);
    perf_stop(&ctx, &cycles, &instret);
    double b_cpp = (double)cycles / total_bc;
    perf_print("B: surprise miss (5+1)", cycles, instret, total_bc, 2);

    /* Test C: always 5+1 pattern */
    test_replay_always_miss(1000, addrs);  /* warmup */
    perf_start(&ctx);
    test_replay_always_miss(NLOOP, addrs);
    perf_stop(&ctx, &cycles, &instret);
    double c_cpp = (double)cycles / total_bc;
    perf_print("C: always 5+1 (learned)", cycles, instret, total_bc, 2);

    printf("\n=== Analysis ===\n");
    printf("  A (all hit)  cycles/pair: %.2f\n", a_cpp);
    printf("  B (surprise) cycles/pair: %.2f\n", b_cpp);
    printf("  C (learned)  cycles/pair: %.2f\n", c_cpp);
    printf("  B - A (miss penalty incl replay): %.2f\n", b_cpp - a_cpp);
    printf("  B - C (pure replay penalty):      %.2f\n", b_cpp - c_cpp);
    printf("  C - A (adapted miss penalty):     %.2f\n", c_cpp - a_cpp);
    printf("\n");
    printf("  B - C > 0 => surprise miss 有额外 replay penalty\n");
    printf("  B - C ~ 0 => scheduler 不做投机唤醒或无 miss predictor\n");

    free(buf);
    perf_close(&ctx);
    return 0;
}
