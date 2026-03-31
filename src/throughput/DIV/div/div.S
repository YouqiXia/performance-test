    .text

# --- DIV: rs1/rs2 signed ---
# Dispatch: DIV → INT Pipe 0
# Expected throughput=1/17, latency=17-18
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_div
    .balign 4
test_div:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_div_loop:
    beqz t3, .L_div_done
    .rept 5
    div  t0, a5, a6
    div  t1, a5, a6
    div  t2, a5, a6
    div  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_div_loop
.L_div_done:
    ret
