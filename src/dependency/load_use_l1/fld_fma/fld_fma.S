    .text

# --- FLD→FMA→FSD (L1) forwarding chain ---
# fld→fmadd.d→fsd round-trip via store forwarding
# Construction: .rept 100, insn_per_iter=3
# ft0 = chain register, ft1=1.0 (mul identity), ft2=0.0 (add identity)
# a1 = fixed L1 address
    .global test_fld_fma
    .balign 4
test_fld_fma:
    mv   t3, a0
    # a1 = FP data buffer (passed by caller)
.L_fld_fma_loop:
    beqz t3, .L_fld_fma_done
    .rept 100
    fld      ft0, 0(a1)
    fmadd.d  ft0, ft0, ft1, ft2
    fsd      ft0, 0(a1)
    .endr
    addi t3, t3, -1
    j    .L_fld_fma_loop
.L_fld_fma_done:
    ret
