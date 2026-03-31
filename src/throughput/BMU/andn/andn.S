    .text

# --- ANDN: rs1&~rs2 ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_andn
    .balign 4
test_andn:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_andn_loop:
    beqz t3, .L_andn_done
    .rept 25
    andn  t0, a5, a6
    andn  t1, a5, a6
    andn  t2, a5, a6
    andn  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_andn_loop
.L_andn_done:
    ret
