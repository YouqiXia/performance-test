    .text

# --- DIVUW: sext32(div32 unsigned) ---
# Dispatch: DIV → INT Pipe 0
# Expected throughput=1/17, latency=17-18
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_divuw
    .balign 4
test_divuw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_divuw_loop:
    beqz t3, .L_divuw_done
    .rept 5
    divuw  t0, a5, a6
    divuw  t1, a5, a6
    divuw  t2, a5, a6
    divuw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_divuw_loop
.L_divuw_done:
    ret
