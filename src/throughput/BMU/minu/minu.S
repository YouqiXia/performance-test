    .text

# --- MINU: min unsigned ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_minu
    .balign 4
test_minu:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_minu_loop:
    beqz t3, .L_minu_done
    .rept 25
    minu  t0, a5, a6
    minu  t1, a5, a6
    minu  t2, a5, a6
    minu  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_minu_loop
.L_minu_done:
    ret
