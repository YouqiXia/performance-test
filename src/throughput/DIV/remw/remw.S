    .text

# --- REMW: sext32(rem32 signed) ---
# Dispatch: DIV → INT Pipe 0
# Expected throughput=1/17, latency=17-18
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_remw
    .balign 4
test_remw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_remw_loop:
    beqz t3, .L_remw_done
    .rept 5
    remw  t0, a5, a6
    remw  t1, a5, a6
    remw  t2, a5, a6
    remw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_remw_loop
.L_remw_done:
    ret
