    .text

# --- SLTU: (rs1<rs2)?1:0 unsigned ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sltu
    .balign 4
test_sltu:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_sltu_loop:
    beqz t3, .L_sltu_done
    .rept 25
    sltu  t0, a5, a6
    sltu  t1, a5, a6
    sltu  t2, a5, a6
    sltu  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_sltu_loop
.L_sltu_done:
    ret
