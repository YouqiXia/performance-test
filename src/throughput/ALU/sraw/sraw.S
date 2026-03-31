    .text

# --- SRAW: sext32(rs1>>rs2 arith) ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sraw
    .balign 4
test_sraw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_sraw_loop:
    beqz t3, .L_sraw_done
    .rept 25
    sraw  t0, a5, a6
    sraw  t1, a5, a6
    sraw  t2, a5, a6
    sraw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_sraw_loop
.L_sraw_done:
    ret
