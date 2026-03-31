    .text

# --- RORI: rotate right imm ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_rori
    .balign 4
test_rori:
    mv   t3, a0
    li  a5, 42
.L_rori_loop:
    beqz t3, .L_rori_done
    .rept 25
    rori  t0, a5, 1
    rori  t1, a5, 1
    rori  t2, a5, 1
    rori  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_rori_loop
.L_rori_done:
    ret
