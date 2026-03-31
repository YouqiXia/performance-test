    .text

# --- FCLASS↔FCVT cross-domain chain ---
# fclass.d→fcvt.d.w round-trip (FP→INT classify, then INT→FP convert)
# Construction: .rept 100, insn_per_iter=2
# t0 = INT chain register, ft0 = FP chain register
# ft0 must be pre-initialized to 1.0 (normal positive) by caller
    .global test_fclass_fcvt
    .balign 4
test_fclass_fcvt:
    mv   t3, a0
.L_fclass_fcvt_loop:
    beqz t3, .L_fclass_fcvt_done
    .rept 100
    fclass.d  t0, ft0
    fcvt.d.w  ft0, t0
    .endr
    addi t3, t3, -1
    j    .L_fclass_fcvt_loop
.L_fclass_fcvt_done:
    ret
