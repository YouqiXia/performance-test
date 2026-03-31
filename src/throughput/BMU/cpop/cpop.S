    .text

# --- CPOP: population count ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_cpop
    .balign 4
test_cpop:
    mv   t3, a0
    li  a5, 0x5A5A5A5A
.L_cpop_loop:
    beqz t3, .L_cpop_done
    .rept 25
    cpop  t0, a5
    cpop  t1, a5
    cpop  t2, a5
    cpop  t4, a5
    .endr
    addi t3, t3, -1
    j    .L_cpop_loop
.L_cpop_done:
    ret
