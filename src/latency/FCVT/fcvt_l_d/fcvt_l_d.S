    .text

# --- FCVT.L.D ---
# FCVT.L.D + FCVT.D.L roundtrip
# Construction: .rept 100, insn_per_iter=2
    .global test_fcvt_l_d
    .balign 4
test_fcvt_l_d:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
.L_fcvt_l_d_loop:
    beqz t3, .L_fcvt_l_d_done
    .rept 100
    fcvt.l.d t0, ft0
    fcvt.d.l ft0, t0
    .endr
    addi t3, t3, -1
    j    .L_fcvt_l_d_loop
.L_fcvt_l_d_done:
    ret
