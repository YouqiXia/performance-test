    .text

# --- SUBW: sext32(rs1-rs2) ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_subw
    .balign 4
test_subw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_subw_loop:
    beqz t3, .L_subw_done
    .rept 25
    subw  t0, a5, a6
    subw  t1, a5, a6
    subw  t2, a5, a6
    subw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_subw_loop
.L_subw_done:
    ret
