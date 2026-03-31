    .text

# --- FSD→FLD→FMV.X.D store address dependency ---
# fsd stores via t0 addr, fld reads back (store fwd), fmv recovers addr
# Construction: .rept 100, insn_per_iter=3
# t0 = INT address, ft0 = FP intermediate
# Pre-loop: fmv.d.x ft0, t0 to init ft0 with valid pointer bits
    .global test_fsd_fld_fmv
    .balign 4
test_fsd_fld_fmv:
    mv   t3, a0
    mv   t0, a1          # t0 = self-loop node pointer
    fmv.d.x  ft0, t0     # CRITICAL: init ft0 so first fsd writes valid pointer
.L_fsd_fld_fmv_loop:
    beqz t3, .L_fsd_fld_fmv_done
    .rept 100
    fsd      ft0, 0(t0)
    fld      ft0, 0(t0)
    fmv.x.d  t0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fsd_fld_fmv_loop
.L_fsd_fld_fmv_done:
    ret
