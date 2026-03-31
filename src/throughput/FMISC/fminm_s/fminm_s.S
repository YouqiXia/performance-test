    .text

# --- FMINM.S: min magnitude S ---
# Dispatch: FMISC → FP Pipe 0
# Expected throughput=1, latency=4
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fminm_s
    .balign 4
test_fminm_s:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fminm_s_loop:
    beqz t3, .L_fminm_s_done
    .rept 25
    fminm.s  ft0, ft8, ft9
    fminm.s  ft1, ft8, ft9
    fminm.s  ft2, ft8, ft9
    fminm.s  ft3, ft8, ft9
    .endr
    addi t3, t3, -1
    j    .L_fminm_s_loop
.L_fminm_s_done:
    ret
