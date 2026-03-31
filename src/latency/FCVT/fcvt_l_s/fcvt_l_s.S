    .text

# --- FCVT.L.S ---
# FCVT.L.S + FCVT.S.L roundtrip
# Construction: .rept 100, insn_per_iter=2
    .global test_fcvt_l_s
    .balign 4
test_fcvt_l_s:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3F800000
    fmv.w.x ft0, t5
.L_fcvt_l_s_loop:
    beqz t3, .L_fcvt_l_s_done
    .rept 100
    fcvt.l.s t0, ft0
    fcvt.s.l ft0, t0
    .endr
    addi t3, t3, -1
    j    .L_fcvt_l_s_loop
.L_fcvt_l_s_done:
    ret
