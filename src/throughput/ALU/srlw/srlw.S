    .text

# --- SRLW: sext32(rs1>>rs2 log) ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_srlw
    .balign 4
test_srlw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_srlw_loop:
    beqz t3, .L_srlw_done
    .rept 25
    srlw  t0, a5, a6
    srlw  t1, a5, a6
    srlw  t2, a5, a6
    srlw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_srlw_loop
.L_srlw_done:
    ret
