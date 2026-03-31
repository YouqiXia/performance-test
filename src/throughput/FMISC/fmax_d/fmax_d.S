    .text

# --- FMAX.D: max ---
# Dispatch: FMISC → FP Pipe 0
# Expected throughput=1, latency=4
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fmax_d
    .balign 4
test_fmax_d:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fmax_d_loop:
    beqz t3, .L_fmax_d_done
    .rept 25
    fmax.d  ft0, ft8, ft9
    fmax.d  ft1, ft8, ft9
    fmax.d  ft2, ft8, ft9
    fmax.d  ft3, ft8, ft9
    .endr
    addi t3, t3, -1
    j    .L_fmax_d_loop
.L_fmax_d_done:
    ret
