    .text

# --- ROR: rotate right ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_ror
    .balign 4
test_ror:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_ror_loop:
    beqz t3, .L_ror_done
    .rept 25
    ror  t0, a5, a6
    ror  t1, a5, a6
    ror  t2, a5, a6
    ror  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_ror_loop
.L_ror_done:
    ret
