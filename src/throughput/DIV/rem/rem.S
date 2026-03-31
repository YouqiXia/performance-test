    .text

# --- REM: rs1%rs2 signed ---
# Dispatch: DIV → INT Pipe 0
# Expected throughput=1/17, latency=17-18
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_rem
    .balign 4
test_rem:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_rem_loop:
    beqz t3, .L_rem_done
    .rept 5
    rem  t0, a5, a6
    rem  t1, a5, a6
    rem  t2, a5, a6
    rem  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_rem_loop
.L_rem_done:
    ret
