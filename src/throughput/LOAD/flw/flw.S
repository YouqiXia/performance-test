    .text

# --- FLW: FP single load ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_flw
    .balign 4
test_flw:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_flw_loop:
    beqz t3, .L_flw_done
    .rept 25
    flw  ft0, 0(a1)
    flw  ft1, 8(a1)
    flw  ft2, 16(a1)
    flw  ft3, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_flw_loop
.L_flw_done:
    ret
