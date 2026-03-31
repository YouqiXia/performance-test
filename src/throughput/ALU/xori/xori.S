    .text

# --- XORI: rs1^imm ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_xori
    .balign 4
test_xori:
    mv   t3, a0
    li  a5, 42
.L_xori_loop:
    beqz t3, .L_xori_done
    .rept 25
    xori  t0, a5, 1
    xori  t1, a5, 1
    xori  t2, a5, 1
    xori  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_xori_loop
.L_xori_done:
    ret
