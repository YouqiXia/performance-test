    .text

# --- ADDW: sext32(rs1+rs2) ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_addw
    .balign 4
test_addw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_addw_loop:
    beqz t3, .L_addw_done
    .rept 25
    addw  t0, a5, a6
    addw  t1, a5, a6
    addw  t2, a5, a6
    addw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_addw_loop
.L_addw_done:
    ret
