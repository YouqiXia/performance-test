    .text

# --- MAXU: max unsigned ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_maxu
    .balign 4
test_maxu:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_maxu_loop:
    beqz t3, .L_maxu_done
    .rept 25
    maxu  t0, a5, a6
    maxu  t1, a5, a6
    maxu  t2, a5, a6
    maxu  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_maxu_loop
.L_maxu_done:
    ret
