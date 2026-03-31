    .text

# --- SLT: (rs1<rs2)?1:0 signed ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_slt
    .balign 4
test_slt:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_slt_loop:
    beqz t3, .L_slt_done
    .rept 25
    slt  t0, a5, a6
    slt  t1, a5, a6
    slt  t2, a5, a6
    slt  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_slt_loop
.L_slt_done:
    ret
