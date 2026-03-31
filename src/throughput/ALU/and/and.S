    .text

# --- AND: rs1&rs2 ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_and
    .balign 4
test_and:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_and_loop:
    beqz t3, .L_and_done
    .rept 25
    and  t0, a5, a6
    and  t1, a5, a6
    and  t2, a5, a6
    and  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_and_loop
.L_and_done:
    ret
