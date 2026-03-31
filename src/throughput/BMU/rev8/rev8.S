    .text

# --- REV8: byte-reverse ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_rev8
    .balign 4
test_rev8:
    mv   t3, a0
    li  a5, 0x5A5A5A5A
.L_rev8_loop:
    beqz t3, .L_rev8_done
    .rept 25
    rev8  t0, a5
    rev8  t1, a5
    rev8  t2, a5
    rev8  t4, a5
    .endr
    addi t3, t3, -1
    j    .L_rev8_loop
.L_rev8_done:
    ret
