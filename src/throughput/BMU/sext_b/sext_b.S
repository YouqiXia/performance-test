    .text

# --- SEXT.B: sign-extend byte ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sext_b
    .balign 4
test_sext_b:
    mv   t3, a0
    li  a5, 0x5A5A5A5A
.L_sext_b_loop:
    beqz t3, .L_sext_b_done
    .rept 25
    sext.b  t0, a5
    sext.b  t1, a5
    sext.b  t2, a5
    sext.b  t4, a5
    .endr
    addi t3, t3, -1
    j    .L_sext_b_loop
.L_sext_b_done:
    ret
