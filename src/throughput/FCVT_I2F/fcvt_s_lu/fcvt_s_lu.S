    .text

# --- FCVT.S.LU: single←uint64 ---
# Dispatch: FCVT.I2F → INT Pipe 3
# Expected throughput=1, latency=4 (FU) / 5 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fcvt_s_lu
    .balign 4
test_fcvt_s_lu:
    mv   t3, a0
    li  a5, 42
.L_fcvt_s_lu_loop:
    beqz t3, .L_fcvt_s_lu_done
    .rept 25
    fcvt.s.lu  ft0, a5
    fcvt.s.lu  ft1, a5
    fcvt.s.lu  ft2, a5
    fcvt.s.lu  ft3, a5
    .endr
    addi t3, t3, -1
    j    .L_fcvt_s_lu_loop
.L_fcvt_s_lu_done:
    ret
