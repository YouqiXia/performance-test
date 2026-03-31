    .text

# --- FLI.S: Load FP immediate S ---
# Dispatch: FMISC → FP Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fli_s
    .balign 4
test_fli_s:
    mv   t3, a0
.L_fli_s_loop:
    beqz t3, .L_fli_s_done
    .rept 25
    fli.s  ft0, 1.0e+0
    fli.s  ft1, 1.0e+0
    fli.s  ft2, 1.0e+0
    fli.s  ft3, 1.0e+0
    .endr
    addi t3, t3, -1
    j    .L_fli_s_loop
.L_fli_s_done:
    ret
