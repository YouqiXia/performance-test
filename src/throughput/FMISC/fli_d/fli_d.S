    .text

# --- FLI.D: Load FP immediate D ---
# Dispatch: FMISC → FP Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fli_d
    .balign 4
test_fli_d:
    mv   t3, a0
.L_fli_d_loop:
    beqz t3, .L_fli_d_done
    .rept 25
    fli.d  ft0, 1.0e+0
    fli.d  ft1, 1.0e+0
    fli.d  ft2, 1.0e+0
    fli.d  ft3, 1.0e+0
    .endr
    addi t3, t3, -1
    j    .L_fli_d_loop
.L_fli_d_done:
    ret
