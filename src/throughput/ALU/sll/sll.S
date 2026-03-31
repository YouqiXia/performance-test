    .text

# --- SLL: rs1<<rs2[5:0] ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sll
    .balign 4
test_sll:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_sll_loop:
    beqz t3, .L_sll_done
    .rept 25
    sll  t0, a5, a6
    sll  t1, a5, a6
    sll  t2, a5, a6
    sll  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_sll_loop
.L_sll_done:
    ret
