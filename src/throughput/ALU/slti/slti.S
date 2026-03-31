    .text

# --- SLTI: (rs1<imm)?1:0 signed ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_slti
    .balign 4
test_slti:
    mv   t3, a0
    li  a5, 42
.L_slti_loop:
    beqz t3, .L_slti_done
    .rept 25
    slti  t0, a5, 1
    slti  t1, a5, 1
    slti  t2, a5, 1
    slti  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_slti_loop
.L_slti_done:
    ret
