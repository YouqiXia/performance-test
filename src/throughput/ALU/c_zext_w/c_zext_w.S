    .text

# --- C.ZEXT.W: zext word ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_zext_w
    .balign 4
test_c_zext_w:
    mv   t3, a0
.L_c_zext_w_loop:
    beqz t3, .L_c_zext_w_done
    .rept 25
    c.zext.w  a2
    c.zext.w  a3
    c.zext.w  a4
    c.zext.w  a5
    .endr
    addi t3, t3, -1
    j    .L_c_zext_w_loop
.L_c_zext_w_done:
    ret
