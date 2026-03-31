    .text

# --- FDIV.S: FP div single ---
# Dispatch: FDIV → FP Pipe 0
# Expected throughput=1/20, latency=20
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_fdiv_s
    .balign 4
test_fdiv_s:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fdiv_s_loop:
    beqz t3, .L_fdiv_s_done
    .rept 5
    fdiv.s  ft0, ft8, ft9
    fdiv.s  ft1, ft8, ft9
    fdiv.s  ft2, ft8, ft9
    fdiv.s  ft3, ft8, ft9
    .endr
    addi t3, t3, -1
    j    .L_fdiv_s_loop
.L_fdiv_s_done:
    ret
