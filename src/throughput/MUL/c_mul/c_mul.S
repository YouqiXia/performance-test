    .text

# --- C.MUL: rd'=rd'*rs2' lower bits ---
# Dispatch: MUL → INT Pipe 2
# Expected throughput=1, latency=3
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_mul
    .balign 4
test_c_mul:
    mv   t3, a0
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    li   s0, 1
.L_c_mul_loop:
    beqz t3, .L_c_mul_done
    .rept 25
    c.mul  a2, s0
    c.mul  a3, s0
    c.mul  a4, s0
    c.mul  a5, s0
    .endr
    addi t3, t3, -1
    j    .L_c_mul_loop
.L_c_mul_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
