# riscv-uarch-bench — RISC-V Microarchitecture Benchmark Suite
#
# Usage:
#   make                        # build all (default ARCH=x100)
#   make ARCH=sunchip           # build with a different arch profile
#   make CROSS_COMPILE=riscv64-unknown-linux-gnu-
#   make spike                  # build for spike+pk simulation
#   make clean

# --- arch profile (arch/<ARCH>.h) ---
ARCH        ?= default
ARCH_HDR    := arch/$(ARCH).h
ifeq ($(wildcard $(ARCH_HDR)),)
$(error Unknown ARCH='$(ARCH)' — missing $(ARCH_HDR). See arch/template.h)
endif

CROSS_COMPILE ?=
CC      := $(CROSS_COMPILE)gcc
# RVA23U64 profile: gc + Zba/Zbb/Zbs (BMU) + Zfh + Zfa + Zicond + Zcb
MARCH       ?= rv64gc_zba_zbb_zbs_zfh_zfa_zicond_zcb_zicboz
SPIKE_MARCH ?= $(MARCH)
CFLAGS  := -O2 -march=$(MARCH) -mabi=lp64d -static -I src/common -I . \
           -DARCH_PROFILE_HEADER='"$(ARCH_HDR)"'
LDFLAGS :=

# --- spike+pk build target ---
SPIKE_CC     ?= $(HOME)/workspace/riscv/bin/riscv64-unknown-linux-gnu-gcc
SPIKE_BIN    ?= $(HOME)/workspace/riscv-spike/bin/spike
SPIKE_PK     ?= $(HOME)/workspace/riscv-pk/build/pk

SRCDIR  := src
BINDIR  := bin
COMMON  := $(wildcard $(SRCDIR)/common/*.c)

# Find all test directories containing main.c (excluding common/)
TESTS := $(shell find $(SRCDIR) -name main.c -not -path '*/common/*')
# e.g. src/dependency/alu_use/main.c -> bin/dependency/alu_use
BINS  := $(patsubst $(SRCDIR)/%/main.c,$(BINDIR)/%,$(TESTS))

.PHONY: all clean list

all: $(BINS)

# Pattern rule: bin/X/Y is built from src/X/Y/main.c + src/X/Y/*.S + common
$(BINDIR)/%: $(SRCDIR)/%/main.c $(COMMON)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $< $(wildcard $(dir $<)*.S) $(COMMON) $(LDFLAGS)

clean:
	rm -rf $(BINDIR)

clean-spike:
	rm -rf bin_spike

distclean: clean clean-spike

# List all discovered tests
list:
	@echo "Tests ($(words $(BINS))):"
	@for b in $(BINS); do echo "  $$b"; done

# --- spike build: cross-compile with -DUSE_SPIKE ---
.PHONY: spike spike-run
spike:
	$(MAKE) CC="$(SPIKE_CC)" MARCH="$(SPIKE_MARCH)" \
		CFLAGS="-O2 -march=$(SPIKE_MARCH) -mabi=lp64d -static -I src/common -I . \
		-DARCH_PROFILE_HEADER='\"$(ARCH_HDR)\"' -DUSE_SPIKE" BINDIR=bin_spike

spike-run: spike
	@for test in $$(find bin_spike -type f -executable | sort); do \
		echo ">>> $${test#bin_spike/}"; \
		$(SPIKE_BIN) --isa=rv64gcv_zba_zbb_zbs_zfh_zfhmin_zfa_zicond_zcb_zicboz_zicbom_zicbop_zicntr_zicsr_zifencei_zimop_zkt_zvbb_zvfhmin_zvkt_zihintpause_zihintntl $(SPIKE_PK) ./$$test; \
		echo ""; \
	done

# --- spike checkpoint build: cross-compile with -DUSE_SPIKE -DCHECKPOINT ---
.PHONY: spike-checkpoint
spike-checkpoint:
	$(MAKE) CC="$(SPIKE_CC)" MARCH="$(SPIKE_MARCH)" \
		CFLAGS="-O2 -march=$(SPIKE_MARCH) -mabi=lp64d -static -I src/common -I . \
		-DARCH_PROFILE_HEADER='\"$(ARCH_HDR)\"' -DUSE_SPIKE -DCHECKPOINT" BINDIR=bin_spike_ckpt
