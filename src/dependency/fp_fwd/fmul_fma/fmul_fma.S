    .text

# --- FMUL↔FMA forwarding chain ---
# fmul.d→fmadd.d→fmul.d round-trip
# Construction: .rept 100, insn_per_iter=2
# ft0 = chain register, ft1=1.0 (fmul identity), ft2=1.0 (fmadd mul identity), ft3=0.0 (fmadd add identity)
    .global test_fmul_fma
    .balign 4
test_fmul_fma:
    mv   t3, a0
.L_fmul_fma_loop:
    beqz t3, .L_fmul_fma_done
    .rept 100
    fmul.d   ft0, ft0, ft1
    fmadd.d  ft0, ft0, ft2, ft3
    .endr
    addi t3, t3, -1
    j    .L_fmul_fma_loop
.L_fmul_fma_done:
    ret
