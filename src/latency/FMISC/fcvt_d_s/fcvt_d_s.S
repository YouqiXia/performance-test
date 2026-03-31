    .text

# --- FCVT.D.S ---
# FCVT.D.S + FCVT.S.D roundtrip, measures sum of both latencies
# Construction: .rept 50, insn_per_iter=2
    .global test_fcvt_d_s
    .balign 4
test_fcvt_d_s:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
    fcvt.s.d ft0, ft0
.L_fcvt_d_s_loop:
    beqz t3, .L_fcvt_d_s_done
    .rept 50
    fcvt.d.s ft0, ft0
    fcvt.s.d ft0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fcvt_d_s_loop
.L_fcvt_d_s_done:
    ret
