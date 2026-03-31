    .text

# --- FLD→FMV.X.D load address dependency ---
# fld loads via pointer in t0, fmv.x.d recovers address for next fld
# Construction: .rept 100, insn_per_iter=2
# t0 = INT address, ft0 = FP intermediate
    .global test_fld_fmv
    .balign 4
test_fld_fmv:
    mv   t3, a0
    mv   t0, a1          # t0 = self-loop node pointer
.L_fld_fmv_loop:
    beqz t3, .L_fld_fmv_done
    .rept 100
    fld      ft0, 0(t0)
    fmv.x.d  t0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fld_fmv_loop
.L_fld_fmv_done:
    ret
