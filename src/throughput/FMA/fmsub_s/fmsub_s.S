    .text

# --- FMSUB.S: Fused multiply-add single ---
# Dispatch: FMA → FP Pipe 0/1
# Expected throughput=2, latency=4
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fmsub_s
    .balign 4
test_fmsub_s:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fmsub_s_loop:
    beqz t3, .L_fmsub_s_done
    .rept 25
    fmsub.s  ft0, ft8, ft9, ft10
    fmsub.s  ft1, ft8, ft9, ft10
    fmsub.s  ft2, ft8, ft9, ft10
    fmsub.s  ft3, ft8, ft9, ft10
    .endr
    addi t3, t3, -1
    j    .L_fmsub_s_loop
.L_fmsub_s_done:
    ret
