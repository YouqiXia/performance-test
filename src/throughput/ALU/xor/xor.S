    .text

# --- XOR: rs1^rs2 ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_xor
    .balign 4
test_xor:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_xor_loop:
    beqz t3, .L_xor_done
    .rept 25
    xor  t0, a5, a6
    xor  t1, a5, a6
    xor  t2, a5, a6
    xor  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_xor_loop
.L_xor_done:
    ret
