    .text

# --- BEXT: (rs1>>rs2)&1 ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_bext
    .balign 4
test_bext:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_bext_loop:
    beqz t3, .L_bext_done
    .rept 25
    bext  t0, a5, a6
    bext  t1, a5, a6
    bext  t2, a5, a6
    bext  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_bext_loop
.L_bext_done:
    ret
