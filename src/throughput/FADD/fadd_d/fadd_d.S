    .text

# --- FADD.D: FP add double ---
# Dispatch: FADD → FP Pipe 0/1
# Expected throughput=2, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fadd_d
    .balign 4
test_fadd_d:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fadd_d_loop:
    beqz t3, .L_fadd_d_done
    .rept 25
    fadd.d  ft0, ft8, ft9
    fadd.d  ft1, ft8, ft9
    fadd.d  ft2, ft8, ft9
    fadd.d  ft3, ft8, ft9
    .endr
    addi t3, t3, -1
    j    .L_fadd_d_loop
.L_fadd_d_done:
    ret
