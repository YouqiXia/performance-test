    .text

# --- SRA: rs1>>rs2[5:0] arith ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sra
    .balign 4
test_sra:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_sra_loop:
    beqz t3, .L_sra_done
    .rept 25
    sra  t0, a5, a6
    sra  t1, a5, a6
    sra  t2, a5, a6
    sra  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_sra_loop
.L_sra_done:
    ret
