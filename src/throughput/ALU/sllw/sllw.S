    .text

# --- SLLW: sext32(rs1<<rs2[4:0]) ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sllw
    .balign 4
test_sllw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_sllw_loop:
    beqz t3, .L_sllw_done
    .rept 25
    sllw  t0, a5, a6
    sllw  t1, a5, a6
    sllw  t2, a5, a6
    sllw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_sllw_loop
.L_sllw_done:
    ret
