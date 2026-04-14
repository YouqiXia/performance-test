WORKSPACE_ROOT ?= /workspace
CROSS_ROOT ?= $(WORKSPACE_ROOT)/toolchains/riscv64-linux-gnu-gcc-current/bin
BAREMETAL_CROSS_COMPILE ?= $(CROSS_ROOT)/riscv64-buildroot-linux-gnu-

BAREMETAL_CC      ?= $(BAREMETAL_CROSS_COMPILE)gcc
BAREMETAL_OBJDUMP ?= $(BAREMETAL_CROSS_COMPILE)objdump

BAREMETAL_MARCH ?= rv64gc_zba_zbb_zbs_zfh_zfa_zicond_zcb_zicboz
BAREMETAL_MABI  ?= lp64d
BAREMETAL_SPIKE_ISA ?= rv64gc_zba_zbb_zbs_zfh_zfa_zicond_zcb_zicboz_zicntr

BAREMETAL_MK := $(abspath $(lastword $(MAKEFILE_LIST)))
BAREMETAL_RUNTIME_DIR := $(dir $(BAREMETAL_MK))
BAREMETAL_REPO_ROOT := $(abspath $(BAREMETAL_RUNTIME_DIR)/../../..)
BAREMETAL_RUNTIME_ASMS := $(BAREMETAL_RUNTIME_DIR)/crt.S
BAREMETAL_RUNTIME_SRCS := \
	$(BAREMETAL_RUNTIME_DIR)/runtime.c \
	$(BAREMETAL_RUNTIME_DIR)/htif_stdio.c

BAREMETAL_COMMON_FLAGS := -march=$(BAREMETAL_MARCH) -mabi=$(BAREMETAL_MABI) \
	-mcmodel=medany -static -ffreestanding -fno-builtin -fno-stack-protector \
	-nostdlib -nostartfiles -O2 -g -Wall -Wextra -DUSE_SPIKE -DBAREMETAL \
	-I $(BAREMETAL_REPO_ROOT)/src/common -I $(BAREMETAL_REPO_ROOT) \
	-I $(BAREMETAL_RUNTIME_DIR) -I $(BAREMETAL_REPO_ROOT)/thirdparty/riscv-pk/machine

BAREMETAL_LDFLAGS := -Wl,--gc-sections -T $(BAREMETAL_RUNTIME_DIR)/link.ld -lgcc
