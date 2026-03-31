/*
 * Architecture Profile Template
 *
 * Copy this file to <your_core>.h and fill in the values.
 * Then build with: make ARCH=<your_core>
 */
#ifndef ARCH_PROFILE_H
#define ARCH_PROFILE_H

#define ARCH_NAME           "TODO"

/* Cache geometry */
#define ARCH_CACHELINE      64              /* bytes (almost always 64) */
#define ARCH_L1D_SIZE       (64 * 1024)     /* L1 data cache size in bytes */
#define ARCH_L1D_WAYS       4               /* L1 data cache associativity */
#define ARCH_L1I_SIZE       (64 * 1024)     /* L1 instruction cache size */

/* Derived: stride between same-set addresses */
#define ARCH_L1D_SET_STRIDE (ARCH_L1D_SIZE / ARCH_L1D_WAYS)

/* Working set sizes for L2-resident tests (must be > L1D) */
#define ARCH_L2_WORKING_SET (1024 * 1024)   /* big enough to miss L1 */
#define ARCH_L2_EVICT_BUF   (256 * 1024)    /* for L1 eviction */

#endif /* ARCH_PROFILE_H */
