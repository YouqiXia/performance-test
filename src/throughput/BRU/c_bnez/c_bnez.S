    .text

# --- C.BNEZ: branch if rs1'!=0 ---
# Dispatch: BRU → INT Pipe 1
# Expected throughput=1, latency=1
# 1 independent insns × .rept 100 = 100 insns/loop

    .global test_c_bnez
    .balign 4
test_c_bnez:
    mv   t3, a0
    addi sp, sp, -16
    sd   s0, 0(sp)
    li   s0, 0
.L_c_bnez_loop:
    beqz t3, .L_c_bnez_done
    .rept 100
    c.bnez  s0, .+4
    .endr
    addi t3, t3, -1
    j    .L_c_bnez_loop
.L_c_bnez_done:
    ld   s0, 0(sp)
    addi sp, sp, 16
    ret
