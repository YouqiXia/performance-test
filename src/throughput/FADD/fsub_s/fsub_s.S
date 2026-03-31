    .text

# --- FSUB.S: FP sub single ---
# Dispatch: FADD → FP Pipe 0/1
# Expected throughput=2, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fsub_s
    .balign 4
test_fsub_s:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fsub_s_loop:
    beqz t3, .L_fsub_s_done
    .rept 25
    fsub.s  ft0, ft8, ft9
    fsub.s  ft1, ft8, ft9
    fsub.s  ft2, ft8, ft9
    fsub.s  ft3, ft8, ft9
    .endr
    addi t3, t3, -1
    j    .L_fsub_s_loop
.L_fsub_s_done:
    ret
