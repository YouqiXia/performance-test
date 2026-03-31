    .text

# --- C.SRAI: rd'>>shamt arith ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_srai
    .balign 4
test_c_srai:
    mv   t3, a0
.L_c_srai_loop:
    beqz t3, .L_c_srai_done
    .rept 25
    c.srai  a2, 1
    c.srai  a3, 1
    c.srai  a4, 1
    c.srai  a5, 1
    .endr
    addi t3, t3, -1
    j    .L_c_srai_loop
.L_c_srai_done:
    ret
