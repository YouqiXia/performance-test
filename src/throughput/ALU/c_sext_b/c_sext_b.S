    .text

# --- C.SEXT.B: sext byte ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_sext_b
    .balign 4
test_c_sext_b:
    mv   t3, a0
.L_c_sext_b_loop:
    beqz t3, .L_c_sext_b_done
    .rept 25
    c.sext.b  a2
    c.sext.b  a3
    c.sext.b  a4
    c.sext.b  a5
    .endr
    addi t3, t3, -1
    j    .L_c_sext_b_loop
.L_c_sext_b_done:
    ret
