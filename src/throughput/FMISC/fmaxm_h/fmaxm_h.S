    .text

# --- FMAXM.H: max magnitude H ---
# Dispatch: FMISC → FP Pipe 0
# Expected throughput=1, latency=4
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fmaxm_h
    .balign 4
test_fmaxm_h:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fmaxm_h_loop:
    beqz t3, .L_fmaxm_h_done
    .rept 25
    fmaxm.h  ft0, ft8, ft9
    fmaxm.h  ft1, ft8, ft9
    fmaxm.h  ft2, ft8, ft9
    fmaxm.h  ft3, ft8, ft9
    .endr
    addi t3, t3, -1
    j    .L_fmaxm_h_loop
.L_fmaxm_h_done:
    ret
