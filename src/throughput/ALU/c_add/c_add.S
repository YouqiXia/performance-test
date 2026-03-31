    .text

# --- C.ADD: rd=rd+rs2 ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_add
    .balign 4
test_c_add:
    mv   t3, a0
    li  a5, 1
.L_c_add_loop:
    beqz t3, .L_c_add_done
    .rept 25
    c.add  t0, a5
    c.add  t1, a5
    c.add  t2, a5
    c.add  t4, a5
    .endr
    addi t3, t3, -1
    j    .L_c_add_loop
.L_c_add_done:
    ret
