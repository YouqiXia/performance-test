    .text

# --- C.XOR: rd'^rs2' ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_xor
    .balign 4
test_c_xor:
    mv   t3, a0
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    li   s0, 1
.L_c_xor_loop:
    beqz t3, .L_c_xor_done
    .rept 25
    c.xor  a2, s0
    c.xor  a3, s0
    c.xor  a4, s0
    c.xor  a5, s0
    .endr
    addi t3, t3, -1
    j    .L_c_xor_loop
.L_c_xor_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
