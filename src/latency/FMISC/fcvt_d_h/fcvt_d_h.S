    .text

# --- FCVT.D.H ---
# FCVT.D.H + FCVT.H.D roundtrip, measures sum of both latencies
# Construction: .rept 50, insn_per_iter=2
    .global test_fcvt_d_h
    .balign 4
test_fcvt_d_h:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
    fcvt.h.d ft0, ft0
.L_fcvt_d_h_loop:
    beqz t3, .L_fcvt_d_h_done
    .rept 50
    fcvt.d.h ft0, ft0
    fcvt.h.d ft0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fcvt_d_h_loop
.L_fcvt_d_h_done:
    ret
