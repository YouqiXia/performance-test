    .text

# --- FCVT.D.L ---
# FCVT.D.L + FCVT.L.D roundtrip
# Construction: .rept 100, insn_per_iter=2
    .global test_fcvt_d_l
    .balign 4
test_fcvt_d_l:
    mv   t3, a0
    # Initialize registers
    li   t0, 1
.L_fcvt_d_l_loop:
    beqz t3, .L_fcvt_d_l_done
    .rept 100
    fcvt.d.l ft0, t0
    fcvt.l.d t0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fcvt_d_l_loop
.L_fcvt_d_l_done:
    ret
