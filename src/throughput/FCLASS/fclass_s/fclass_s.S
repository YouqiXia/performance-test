    .text

# --- FCLASS.S: Classify FP single ---
# Dispatch: FCLASS → FP Pipe 1
# Expected throughput=1, latency=1 (FU) / 2 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fclass_s
    .balign 4
test_fclass_s:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fclass_s_loop:
    beqz t3, .L_fclass_s_done
    .rept 25
    fclass.s  t0, ft8
    fclass.s  t1, ft8
    fclass.s  t2, ft8
    fclass.s  t4, ft8
    .endr
    addi t3, t3, -1
    j    .L_fclass_s_loop
.L_fclass_s_done:
    ret
