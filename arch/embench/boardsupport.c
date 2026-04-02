/* Board support for Linux RISC-V — prints cycles, instructions, IPC.
   Uses perf_event_open (like perf_helpers.c), falls back to rdcycle/rdinstret.
   SPDX-License-Identifier: GPL-3.0-or-later */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <linux/perf_event.h>
#include "support.h"

static int use_fallback;
static int fd_cycles  = -1;
static int fd_instret = -1;

/* fallback state for rdcycle/rdinstret */
static uint64_t fb_cyc_start, fb_inst_start;

static long sys_perf_event_open(struct perf_event_attr *attr, pid_t pid,
                                int cpu, int group_fd, unsigned long flags)
{
    return syscall(__NR_perf_event_open, attr, pid, cpu, group_fd, flags);
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

void initialise_board(void)
{
    struct perf_event_attr pe;
    memset(&pe, 0, sizeof(pe));
    pe.size = sizeof(pe);
    pe.disabled = 1;
    pe.exclude_kernel = 1;
    pe.exclude_hv = 1;

    pe.type = PERF_TYPE_HARDWARE;
    pe.config = PERF_COUNT_HW_CPU_CYCLES;
    fd_cycles = sys_perf_event_open(&pe, 0, -1, -1, 0);
    if (fd_cycles < 0) {
        use_fallback = 1;
        return;
    }

    pe.config = PERF_COUNT_HW_INSTRUCTIONS;
    fd_instret = sys_perf_event_open(&pe, 0, -1, -1, 0);
    if (fd_instret < 0) {
        close(fd_cycles);
        fd_cycles = -1;
        use_fallback = 1;
    }
}

void __attribute__((noinline)) __attribute__((externally_visible))
start_trigger(void)
{
    if (use_fallback) {
        __asm__ volatile ("fence" ::: "memory");
        fb_inst_start = rdinstret();
        fb_cyc_start  = rdcycle();
        return;
    }
    ioctl(fd_cycles,  PERF_EVENT_IOC_RESET, 0);
    ioctl(fd_instret, PERF_EVENT_IOC_RESET, 0);
    ioctl(fd_cycles,  PERF_EVENT_IOC_ENABLE, 0);
    ioctl(fd_instret, PERF_EVENT_IOC_ENABLE, 0);
}

void __attribute__((noinline)) __attribute__((externally_visible))
stop_trigger(void)
{
    uint64_t dc, di;

    if (use_fallback) {
        uint64_t c = rdcycle();
        uint64_t i = rdinstret();
        __asm__ volatile ("fence" ::: "memory");
        dc = c - fb_cyc_start;
        di = i - fb_inst_start;
    } else {
        ioctl(fd_cycles,  PERF_EVENT_IOC_DISABLE, 0);
        ioctl(fd_instret, PERF_EVENT_IOC_DISABLE, 0);
        read(fd_cycles,  &dc, sizeof(dc));
        read(fd_instret, &di, sizeof(di));
        close(fd_cycles);
        close(fd_instret);
    }

    const char *name = program_invocation_short_name;
    double cyc_iter  = (double)dc;
    double insn_iter = (double)di;
    double ipc = (di > 0 && dc > 0) ? (double)di / dc : 0.0;

    printf("  [%-30s]  cycles/iter: %7.2f  insn/iter: %5.2f  IPC: %.4f  "
           "(cycles: %lu, instret: %lu)\n",
           name, cyc_iter, insn_iter, ipc, dc, di);

    printf("##PERF##|%s|%.4f|%.4f|%.6f|%lu|%lu|1|0##\n",
           name, cyc_iter, insn_iter, ipc, dc, di);
}
