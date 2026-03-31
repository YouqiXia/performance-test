    .text

# --- SEXT.H: sign-extend half ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sext_h
    .balign 4
test_sext_h:
    mv   t3, a0
    li  a5, 0x5A5A5A5A
.L_sext_h_loop:
    beqz t3, .L_sext_h_done
    .rept 25
    sext.h  t0, a5
    sext.h  t1, a5
    sext.h  t2, a5
    sext.h  t4, a5
    .endr
    addi t3, t3, -1
    j    .L_sext_h_loop
.L_sext_h_done:
    ret
