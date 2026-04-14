#include "perf_helpers.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(__linux__) && !defined(BAREMETAL)
#define HAS_PERF_EVENT 1
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <linux/perf_event.h>
#endif

#ifdef HAS_PERF_EVENT
static int use_fallback = 0;
#else
static int use_fallback = 1;  /* spike/baremetal: always use rdcycle/rdinstret */
#endif

#ifdef HAS_PERF_EVENT
static long sys_perf_event_open(struct perf_event_attr *attr, pid_t pid,
                                int cpu, int group_fd, unsigned long flags)
{
    return syscall(__NR_perf_event_open, attr, pid, cpu, group_fd, flags);
}
#endif

perf_ctx_t perf_init(void)
{
    perf_ctx_t ctx;
    ctx.fd_cycles = -1;
    ctx.fd_instret = -1;

#ifdef CHECKPOINT
    /* Preload all ELF pages then trigger checkpoint.
       Must run BEFORE perf_event_open — on spike+pk, perf_event_open fails
       and would early-return, skipping this block.
       Restore resumes here — warmup and measurement run normally. */
    {
        extern char __ehdr_start[], _end[];
        volatile char dummy;
        for (char *p = __ehdr_start; p < _end; p += 4096)
            dummy = *p;
    }
    __asm__ volatile ("csrw 0x800, x0");
#endif

#ifdef HAS_PERF_EVENT
    struct perf_event_attr pe;

    memset(&pe, 0, sizeof(pe));
    pe.size = sizeof(pe);
    pe.disabled = 1;
    pe.exclude_kernel = 1;
    pe.exclude_hv = 1;

    /* cycles */
    pe.type = PERF_TYPE_HARDWARE;
    pe.config = PERF_COUNT_HW_CPU_CYCLES;
    ctx.fd_cycles = sys_perf_event_open(&pe, 0, -1, -1, 0);
    if (ctx.fd_cycles < 0) {
        fprintf(stderr, "[perf] perf_event_open failed, falling back to rdcycle/rdinstret\n");
        fprintf(stderr, "  Try: echo -1 > /proc/sys/kernel/perf_event_paranoid\n");
        use_fallback = 1;
        ctx.fd_cycles = -1;
        ctx.fd_instret = -1;
        return ctx;
    }

    /* instructions */
    pe.config = PERF_COUNT_HW_INSTRUCTIONS;
    ctx.fd_instret = sys_perf_event_open(&pe, 0, -1, -1, 0);
    if (ctx.fd_instret < 0) {
        fprintf(stderr, "[perf] instructions counter failed, falling back\n");
        close(ctx.fd_cycles);
        use_fallback = 1;
        ctx.fd_cycles = -1;
        ctx.fd_instret = -1;
    }
#else
    fprintf(stderr, "[perf] spike mode: using rdcycle/rdinstret\n");
#endif

    return ctx;
}

static inline uint64_t rdcycle(void)
{
    uint64_t v;
    __asm__ volatile ("rdcycle %0" : "=r"(v));
    return v;
}

static inline uint64_t rdinstret(void)
{
    uint64_t v;
    __asm__ volatile ("rdinstret %0" : "=r"(v));
    return v;
}

static uint64_t fb_cyc_start, fb_inst_start;

void perf_start(perf_ctx_t *ctx)
{
    if (use_fallback) {
        __asm__ volatile ("fence" ::: "memory");
        fb_inst_start = rdinstret();
        fb_cyc_start = rdcycle();
        return;
    }
#ifdef HAS_PERF_EVENT
    ioctl(ctx->fd_cycles,  PERF_EVENT_IOC_RESET, 0);
    ioctl(ctx->fd_instret, PERF_EVENT_IOC_RESET, 0);
    ioctl(ctx->fd_cycles,  PERF_EVENT_IOC_ENABLE, 0);
    ioctl(ctx->fd_instret, PERF_EVENT_IOC_ENABLE, 0);
#endif
}

void perf_stop(perf_ctx_t *ctx, uint64_t *cycles, uint64_t *instret)
{
    if (use_fallback) {
        uint64_t c = rdcycle();
        uint64_t i = rdinstret();
        __asm__ volatile ("fence" ::: "memory");
        *cycles = c - fb_cyc_start;
        *instret = i - fb_inst_start;
        return;
    }
#ifdef HAS_PERF_EVENT
    ioctl(ctx->fd_cycles,  PERF_EVENT_IOC_DISABLE, 0);
    ioctl(ctx->fd_instret, PERF_EVENT_IOC_DISABLE, 0);
    read(ctx->fd_cycles,  cycles,  sizeof(*cycles));
    read(ctx->fd_instret, instret, sizeof(*instret));
#endif
}

void perf_close(perf_ctx_t *ctx)
{
#ifdef HAS_PERF_EVENT
    if (ctx->fd_cycles >= 0)  close(ctx->fd_cycles);
    if (ctx->fd_instret >= 0) close(ctx->fd_instret);
#endif
    (void)ctx;
}

void perf_print(const char *name, uint64_t cycles, uint64_t instret,
                uint64_t total_iters, uint64_t instr_per_iter)
{
    double cyc_iter = (double)cycles / total_iters;
    double ipc = (instret > 0 && cycles > 0) ? (double)instret / cycles : 0;
    double insn_iter = (double)instret / total_iters;

    /* Human-readable line */
    printf("  [%-30s]  cycles/iter: %7.2f  insn/iter: %5.2f  IPC: %.4f  "
           "(cycles: %lu, instret: %lu)\n",
           name, cyc_iter, insn_iter, ipc, cycles, instret);

    /* Machine-readable marker line — grep '##PERF##' to extract all results.
     * Format: ##PERF##|name|cycles_per_iter|insn_per_iter|ipc|cycles|instret|total_iters|instr_per_iter## */
    printf("##PERF##|%s|%.4f|%.4f|%.6f|%lu|%lu|%lu|%lu##\n",
           name, cyc_iter, insn_iter, ipc, cycles, instret,
           total_iters, instr_per_iter);
}
