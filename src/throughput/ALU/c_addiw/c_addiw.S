    .text

# --- C.ADDIW: sext32(rd+imm) ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_addiw
    .balign 4
test_c_addiw:
    mv   t3, a0
.L_c_addiw_loop:
    beqz t3, .L_c_addiw_done
    .rept 25
    c.addiw  t0, 1
    c.addiw  t1, 1
    c.addiw  t2, 1
    c.addiw  t4, 1
    .endr
    addi t3, t3, -1
    j    .L_c_addiw_loop
.L_c_addiw_done:
    ret
