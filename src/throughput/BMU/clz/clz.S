    .text

# --- CLZ: count leading zeros ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_clz
    .balign 4
test_clz:
    mv   t3, a0
    li  a5, 0x5A5A5A5A
.L_clz_loop:
    beqz t3, .L_clz_done
    .rept 25
    clz  t0, a5
    clz  t1, a5
    clz  t2, a5
    clz  t4, a5
    .endr
    addi t3, t3, -1
    j    .L_clz_loop
.L_clz_done:
    ret
