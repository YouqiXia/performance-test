    .text

# --- C.SUBW: sext32(rd'-rs2') ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_subw
    .balign 4
test_c_subw:
    mv   t3, a0
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    li   s0, 1
.L_c_subw_loop:
    beqz t3, .L_c_subw_done
    .rept 25
    c.subw  a2, s0
    c.subw  a3, s0
    c.subw  a4, s0
    c.subw  a5, s0
    .endr
    addi t3, t3, -1
    j    .L_c_subw_loop
.L_c_subw_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
