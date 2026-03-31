    .text

# --- MUL: (rs1*rs2)[63:0] ---
# Dispatch: MUL → INT Pipe 2
# Expected throughput=1, latency=3
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_mul
    .balign 4
test_mul:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_mul_loop:
    beqz t3, .L_mul_done
    .rept 25
    mul  t0, a5, a6
    mul  t1, a5, a6
    mul  t2, a5, a6
    mul  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_mul_loop
.L_mul_done:
    ret
