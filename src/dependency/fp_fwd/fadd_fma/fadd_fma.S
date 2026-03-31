    .text

# --- FADD↔FMA forwarding chain ---
# fadd.d→fmadd.d→fadd.d round-trip
# Construction: .rept 100, insn_per_iter=2
# ft0 = chain register, ft1=0.0 (fadd identity), ft2=1.0 (fmadd mul identity), ft3=0.0 (fmadd add identity)
    .global test_fadd_fma
    .balign 4
test_fadd_fma:
    mv   t3, a0
.L_fadd_fma_loop:
    beqz t3, .L_fadd_fma_done
    .rept 100
    fadd.d   ft0, ft0, ft1
    fmadd.d  ft0, ft0, ft2, ft3
    .endr
    addi t3, t3, -1
    j    .L_fadd_fma_loop
.L_fadd_fma_done:
    ret
