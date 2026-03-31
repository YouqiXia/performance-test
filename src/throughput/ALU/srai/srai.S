    .text

# --- SRAI: rs1>>shamt arith ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_srai
    .balign 4
test_srai:
    mv   t3, a0
    li  a5, 42
.L_srai_loop:
    beqz t3, .L_srai_done
    .rept 25
    srai  t0, a5, 1
    srai  t1, a5, 1
    srai  t2, a5, 1
    srai  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_srai_loop
.L_srai_done:
    ret
