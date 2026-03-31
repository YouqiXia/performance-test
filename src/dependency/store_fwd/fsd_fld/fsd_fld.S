    .text

# --- FSD↔FLD FP store forwarding ---
# fsd→fld round-trip via store buffer forwarding
# Construction: .rept 100, insn_per_iter=2
# ft0 = chain register, a1 = fixed memory address
    .global test_fsd_fld
    .balign 4
test_fsd_fld:
    mv   t3, a0
    # a1 = buffer address (passed by caller)
.L_fsd_fld_loop:
    beqz t3, .L_fsd_fld_done
    .rept 100
    fsd  ft0, 0(a1)
    fld  ft0, 0(a1)
    .endr
    addi t3, t3, -1
    j    .L_fsd_fld_loop
.L_fsd_fld_done:
    ret
