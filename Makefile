# riscv-uarch-bench — RISC-V Microarchitecture Benchmark Suite
#
# Usage:
#   make                        # cross-compile for Linux (bin/linux/)
#   make spike                  # compile for spike+pk (bin/spike/)
#   make checkpoint             # compile for spike checkpoint (bin/checkpoint/)
#   make spike-run              # compile + run all on spike
#   make clean                  # remove all build artifacts

# --- environment (from env/) ---
-include env/$(or $(UARCH_ENV),default).env

RISCV_TOOLCHAIN     ?= /opt/riscv
RISCV_ELF_TOOLCHAIN ?= $(RISCV_TOOLCHAIN)
MARCH               ?= rv64gc
ARCH                ?= default
ARCH_HDR        := arch/$(ARCH).h

ifeq ($(wildcard $(ARCH_HDR)),)
$(error Unknown ARCH='$(ARCH)' — missing $(ARCH_HDR). See arch/template.h)
endif

# --- toolchain derivation ---
LINUX_CC := $(RISCV_TOOLCHAIN)/bin/riscv64-unknown-linux-gnu-gcc
ELF_CC   := $(RISCV_ELF_TOOLCHAIN)/bin/riscv64-unknown-elf-gcc

# --- install/ paths (populated by uarch build thirdparty) ---
SPIKE_BIN := install/riscv-isa-sim/bin/spike
SPIKE_PK  := install/pk/pk

# --- defaults ---
BINDIR  ?= bin/linux
CC      := $(LINUX_CC)
CFLAGS  := -O2 -march=$(MARCH) -mabi=lp64d -static -I src/common -I . \
           -DARCH_PROFILE_HEADER='"$(ARCH_HDR)"'
LDFLAGS :=

SRCDIR  := src
COMMON  := $(wildcard $(SRCDIR)/common/*.c)

# Find all test directories containing main.c (excluding common/)
TESTS := $(shell find $(SRCDIR) -name main.c -not -path '*/common/*')
BINS  := $(patsubst $(SRCDIR)/%/main.c,$(BINDIR)/%,$(TESTS))

.PHONY: all spike checkpoint spike-run clean distclean list

all: $(BINS)

# Pattern rule: bin/X/Y is built from src/X/Y/main.c + src/X/Y/*.S + common
$(BINDIR)/%: $(SRCDIR)/%/main.c $(COMMON)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $< $(wildcard $(dir $<)*.S) $(COMMON) $(LDFLAGS)

# --- spike: cross-compile with -DUSE_SPIKE ---
# Uses recursive make because BINDIR must be set at parse time (affects BINS list)
spike:
	$(MAKE) CC="$(LINUX_CC)" BINDIR=bin/spike \
		CFLAGS="-O2 -march=$(MARCH) -mabi=lp64d -static -I src/common -I . \
		-DARCH_PROFILE_HEADER='\"$(ARCH_HDR)\"' -DUSE_SPIKE"

# --- checkpoint: cross-compile with -DUSE_SPIKE -DCHECKPOINT ---
checkpoint:
	$(MAKE) CC="$(LINUX_CC)" BINDIR=bin/checkpoint \
		CFLAGS="-O2 -march=$(MARCH) -mabi=lp64d -static -I src/common -I . \
		-DARCH_PROFILE_HEADER='\"$(ARCH_HDR)\"' -DUSE_SPIKE -DCHECKPOINT"

# --- spike-run: build + run all spike tests ---
spike-run: spike
	@for test in $$(find bin/spike -type f -executable | sort); do \
		echo ">>> $${test#bin/spike/}"; \
		$(SPIKE_BIN) --isa=$(MARCH) $(SPIKE_PK) ./$$test; \
		echo ""; \
	done

# --- housekeeping ---
clean:
	rm -rf bin/

distclean: clean
	rm -rf install/

list:
	@echo "Tests ($(words $(BINS))):"
	@for b in $(BINS); do echo "  $$b"; done
