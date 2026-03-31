    .text

# --- ORI: rs1|imm ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_ori
    .balign 4
test_ori:
    mv   t3, a0
    li  a5, 42
.L_ori_loop:
    beqz t3, .L_ori_done
    .rept 25
    ori  t0, a5, 1
    ori  t1, a5, 1
    ori  t2, a5, 1
    ori  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_ori_loop
.L_ori_done:
    ret
