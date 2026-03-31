    .text

# --- DIVW: sext32(div32 signed) ---
# Dispatch: DIV → INT Pipe 0
# Expected throughput=1/17, latency=17-18
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_divw
    .balign 4
test_divw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_divw_loop:
    beqz t3, .L_divw_done
    .rept 5
    divw  t0, a5, a6
    divw  t1, a5, a6
    divw  t2, a5, a6
    divw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_divw_loop
.L_divw_done:
    ret
