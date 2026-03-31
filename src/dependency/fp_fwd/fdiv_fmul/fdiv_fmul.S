    .text

# --- FDIV↔FMUL forwarding chain ---
# fdiv.d→fmul.d→fdiv.d round-trip
# Construction: .rept 20, insn_per_iter=2
# ft0 = chain register, ft1=1.0 (div identity), ft2=1.0 (mul identity)
    .global test_fdiv_fmul
    .balign 4
test_fdiv_fmul:
    mv   t3, a0
.L_fdiv_fmul_loop:
    beqz t3, .L_fdiv_fmul_done
    .rept 20
    fdiv.d  ft0, ft0, ft1
    fmul.d  ft0, ft0, ft2
    .endr
    addi t3, t3, -1
    j    .L_fdiv_fmul_loop
.L_fdiv_fmul_done:
    ret
