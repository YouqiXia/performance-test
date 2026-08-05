    .text

# --- C.JR: PC=rs1 ---
# Dispatch: BRU → INT Pipe 1
# Expected throughput=1, latency=1
# 3 executed insns × .rept 33 = 99 insns/loop

    .global test_c_jr
    .balign 4
test_c_jr:
    mv   t3, a0
.L_c_jr_loop:
    beqz t3, .L_c_jr_done
    .rept 33
    .option push
    .option norvc
    auipc a5, 0
    addi a5, a5, 12
    .option pop
    c.jr  a5
    c.nop
    .endr
    addi t3, t3, -1
    j    .L_c_jr_loop
.L_c_jr_done:
    ret
