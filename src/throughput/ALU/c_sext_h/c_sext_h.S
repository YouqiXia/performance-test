    .text

# --- C.SEXT.H: sext half ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_sext_h
    .balign 4
test_c_sext_h:
    mv   t3, a0
.L_c_sext_h_loop:
    beqz t3, .L_c_sext_h_done
    .rept 25
    c.sext.h  a2
    c.sext.h  a3
    c.sext.h  a4
    c.sext.h  a5
    .endr
    addi t3, t3, -1
    j    .L_c_sext_h_loop
.L_c_sext_h_done:
    ret
