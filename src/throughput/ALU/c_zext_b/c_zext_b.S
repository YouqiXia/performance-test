    .text

# --- C.ZEXT.B: zext byte ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_zext_b
    .balign 4
test_c_zext_b:
    mv   t3, a0
.L_c_zext_b_loop:
    beqz t3, .L_c_zext_b_done
    .rept 25
    c.zext.b  a2
    c.zext.b  a3
    c.zext.b  a4
    c.zext.b  a5
    .endr
    addi t3, t3, -1
    j    .L_c_zext_b_loop
.L_c_zext_b_done:
    ret
