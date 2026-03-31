    .text

# --- SUB: rs1-rs2 ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sub
    .balign 4
test_sub:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_sub_loop:
    beqz t3, .L_sub_done
    .rept 25
    sub  t0, a5, a6
    sub  t1, a5, a6
    sub  t2, a5, a6
    sub  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_sub_loop
.L_sub_done:
    ret
