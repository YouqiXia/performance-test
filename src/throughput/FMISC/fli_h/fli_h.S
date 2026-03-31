    .text

# --- FLI.H: Load FP immediate H ---
# Dispatch: FMISC → FP Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fli_h
    .balign 4
test_fli_h:
    mv   t3, a0
.L_fli_h_loop:
    beqz t3, .L_fli_h_done
    .rept 25
    fli.h  ft0, 1.0e+0
    fli.h  ft1, 1.0e+0
    fli.h  ft2, 1.0e+0
    fli.h  ft3, 1.0e+0
    .endr
    addi t3, t3, -1
    j    .L_fli_h_loop
.L_fli_h_done:
    ret
