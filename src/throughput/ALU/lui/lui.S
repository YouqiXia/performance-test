    .text

# --- LUI: rd=imm<<12 ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_lui
    .balign 4
test_lui:
    mv   t3, a0
.L_lui_loop:
    beqz t3, .L_lui_done
    .rept 25
    lui  t0, 1
    lui  t1, 1
    lui  t2, 1
    lui  t4, 1
    .endr
    addi t3, t3, -1
    j    .L_lui_loop
.L_lui_done:
    ret
