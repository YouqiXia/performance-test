    .text

# --- DIVU: rs1/rs2 unsigned ---
# Dispatch: DIV → INT Pipe 0
# Expected throughput=1/17, latency=17-18
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_divu
    .balign 4
test_divu:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_divu_loop:
    beqz t3, .L_divu_done
    .rept 5
    divu  t0, a5, a6
    divu  t1, a5, a6
    divu  t2, a5, a6
    divu  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_divu_loop
.L_divu_done:
    ret
