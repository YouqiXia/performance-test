    .text

# --- BEXTI: (rs1>>shamt)&1 ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_bexti
    .balign 4
test_bexti:
    mv   t3, a0
    li  a5, 42
.L_bexti_loop:
    beqz t3, .L_bexti_done
    .rept 25
    bexti  t0, a5, 1
    bexti  t1, a5, 1
    bexti  t2, a5, 1
    bexti  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_bexti_loop
.L_bexti_done:
    ret
