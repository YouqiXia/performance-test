    .text

# --- REMUW: sext32(rem32 unsigned) ---
# Dispatch: DIV → INT Pipe 0
# Expected throughput=1/17, latency=17-18
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_remuw
    .balign 4
test_remuw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_remuw_loop:
    beqz t3, .L_remuw_done
    .rept 5
    remuw  t0, a5, a6
    remuw  t1, a5, a6
    remuw  t2, a5, a6
    remuw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_remuw_loop
.L_remuw_done:
    ret
