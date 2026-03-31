    .text

# --- FSGNJ.D: sign inject ---
# Dispatch: FMISC → FP Pipe 0
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fsgnj_d
    .balign 4
test_fsgnj_d:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fsgnj_d_loop:
    beqz t3, .L_fsgnj_d_done
    .rept 25
    fsgnj.d  ft0, ft8, ft9
    fsgnj.d  ft1, ft8, ft9
    fsgnj.d  ft2, ft8, ft9
    fsgnj.d  ft3, ft8, ft9
    .endr
    addi t3, t3, -1
    j    .L_fsgnj_d_loop
.L_fsgnj_d_done:
    ret
