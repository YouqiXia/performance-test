/*
 * Architecture Parameters — unified entry point
 *
 * Each test includes this header; the actual values come from
 * arch/<profile>.h, selected at build time via:
 *
 *   make ARCH=x100          (default)
 *   make ARCH=sunchip
 *
 * The Makefile passes -DARCH_PROFILE_HEADER="arch/x100.h" etc.
 */
#ifndef ARCH_PARAMS_H
#define ARCH_PARAMS_H

/* Include the profile selected by the build system */
#ifndef ARCH_PROFILE_HEADER
#define ARCH_PROFILE_HEADER "arch/default.h"
#endif

#include ARCH_PROFILE_HEADER

/* Validate required macros */
#ifndef ARCH_NAME
#error "ARCH_NAME must be defined in the arch profile"
#endif
#ifndef ARCH_CACHELINE
#error "ARCH_CACHELINE must be defined in the arch profile"
#endif
#ifndef ARCH_L1D_SIZE
#error "ARCH_L1D_SIZE must be defined in the arch profile"
#endif
#ifndef ARCH_L1D_WAYS
#error "ARCH_L1D_WAYS must be defined in the arch profile"
#endif
#ifndef ARCH_L2_WORKING_SET
#error "ARCH_L2_WORKING_SET must be defined in the arch profile"
#endif

/* Derived macros (profiles can override) */
#ifndef ARCH_L1D_SET_STRIDE
#define ARCH_L1D_SET_STRIDE (ARCH_L1D_SIZE / ARCH_L1D_WAYS)
#endif

#endif /* ARCH_PARAMS_H */
