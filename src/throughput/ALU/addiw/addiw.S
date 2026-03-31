    .text

# --- ADDIW: sext32(rs1+imm) ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_addiw
    .balign 4
test_addiw:
    mv   t3, a0
    li  a5, 42
.L_addiw_loop:
    beqz t3, .L_addiw_done
    .rept 25
    addiw  t0, a5, 1
    addiw  t1, a5, 1
    addiw  t2, a5, 1
    addiw  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_addiw_loop
.L_addiw_done:
    ret
