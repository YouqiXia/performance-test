    .text

# --- C.OR: rd'|rs2' ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_or
    .balign 4
test_c_or:
    mv   t3, a0
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    li   s0, 1
.L_c_or_loop:
    beqz t3, .L_c_or_done
    .rept 25
    c.or  a2, s0
    c.or  a3, s0
    c.or  a4, s0
    c.or  a5, s0
    .endr
    addi t3, t3, -1
    j    .L_c_or_loop
.L_c_or_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
