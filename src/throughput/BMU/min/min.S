    .text

# --- MIN: min signed ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_min
    .balign 4
test_min:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_min_loop:
    beqz t3, .L_min_done
    .rept 25
    min  t0, a5, a6
    min  t1, a5, a6
    min  t2, a5, a6
    min  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_min_loop
.L_min_done:
    ret
