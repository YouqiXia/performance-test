    .text

# --- XNOR: ~(rs1^rs2) ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_xnor
    .balign 4
test_xnor:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_xnor_loop:
    beqz t3, .L_xnor_done
    .rept 25
    xnor  t0, a5, a6
    xnor  t1, a5, a6
    xnor  t2, a5, a6
    xnor  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_xnor_loop
.L_xnor_done:
    ret
