    .text

# --- FLD→FADD→FSD (L1) forwarding chain ---
# fld→fadd.d→fsd round-trip via store forwarding
# Construction: .rept 100, insn_per_iter=3
# ft0 = chain register, ft1=0.0 (add identity), a1 = fixed L1 address
    .global test_fld_fadd
    .balign 4
test_fld_fadd:
    mv   t3, a0
    # a1 = FP data buffer (passed by caller)
.L_fld_fadd_loop:
    beqz t3, .L_fld_fadd_done
    .rept 100
    fld     ft0, 0(a1)
    fadd.d  ft0, ft0, ft1
    fsd     ft0, 0(a1)
    .endr
    addi t3, t3, -1
    j    .L_fld_fadd_loop
.L_fld_fadd_done:
    ret
