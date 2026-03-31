    .text

# --- FLH: FP half load ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_flh
    .balign 4
test_flh:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_flh_loop:
    beqz t3, .L_flh_done
    .rept 25
    flh  ft0, 0(a1)
    flh  ft1, 8(a1)
    flh  ft2, 16(a1)
    flh  ft3, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_flh_loop
.L_flh_done:
    ret
