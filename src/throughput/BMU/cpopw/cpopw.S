    .text

# --- CPOPW: CPOP word ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_cpopw
    .balign 4
test_cpopw:
    mv   t3, a0
    li  a5, 0x5A5A5A5A
.L_cpopw_loop:
    beqz t3, .L_cpopw_done
    .rept 25
    cpopw  t0, a5
    cpopw  t1, a5
    cpopw  t2, a5
    cpopw  t4, a5
    .endr
    addi t3, t3, -1
    j    .L_cpopw_loop
.L_cpopw_done:
    ret
