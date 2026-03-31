    .text

# --- C.ZEXT.H: zext half ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_zext_h
    .balign 4
test_c_zext_h:
    mv   t3, a0
.L_c_zext_h_loop:
    beqz t3, .L_c_zext_h_done
    .rept 25
    c.zext.h  a2
    c.zext.h  a3
    c.zext.h  a4
    c.zext.h  a5
    .endr
    addi t3, t3, -1
    j    .L_c_zext_h_loop
.L_c_zext_h_done:
    ret
