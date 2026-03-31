    .text

# --- C.LUI: rd=imm<<12 ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_lui
    .balign 4
test_c_lui:
    mv   t3, a0
.L_c_lui_loop:
    beqz t3, .L_c_lui_done
    .rept 25
    c.lui  t0, 1
    c.lui  t1, 1
    c.lui  t2, 1
    c.lui  t4, 1
    .endr
    addi t3, t3, -1
    j    .L_c_lui_loop
.L_c_lui_done:
    ret
