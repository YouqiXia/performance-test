    .text

# --- C.AND: rd'&rs2' ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_and
    .balign 4
test_c_and:
    mv   t3, a0
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    li   s0, 1
.L_c_and_loop:
    beqz t3, .L_c_and_done
    .rept 25
    c.and  a2, s0
    c.and  a3, s0
    c.and  a4, s0
    c.and  a5, s0
    .endr
    addi t3, t3, -1
    j    .L_c_and_loop
.L_c_and_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
