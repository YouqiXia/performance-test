/*
 * Default Architecture Profile
 *
 * 4-wide dispatch OoO RISC-V core, 64KB 4-way L1D
 */
#ifndef ARCH_PROFILE_H
#define ARCH_PROFILE_H

#define ARCH_NAME           "default"

/* Cache geometry */
#define ARCH_CACHELINE      64          /* bytes */
#define ARCH_L1D_SIZE       (64 * 1024) /* 64KB */
#define ARCH_L1D_WAYS       4
#define ARCH_L1I_SIZE       (64 * 1024) /* 64KB */

/* Derived: stride between same-set addresses */
#define ARCH_L1D_SET_STRIDE (ARCH_L1D_SIZE / ARCH_L1D_WAYS)  /* 16KB */

/* Working set sizes for L2-resident tests (must be > L1D) */
#define ARCH_L2_WORKING_SET (1024 * 1024)   /* 1MB */
#define ARCH_L2_EVICT_BUF   (256 * 1024)    /* 256KB, for L1 eviction */

#endif /* ARCH_PROFILE_H */
