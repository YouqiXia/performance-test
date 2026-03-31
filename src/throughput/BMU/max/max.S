    .text

# --- MAX: max signed ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_max
    .balign 4
test_max:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_max_loop:
    beqz t3, .L_max_done
    .rept 25
    max  t0, a5, a6
    max  t1, a5, a6
    max  t2, a5, a6
    max  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_max_loop
.L_max_done:
    ret
