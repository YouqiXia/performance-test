    .text

# --- FADD↔FMUL forwarding chain ---
# fadd.d→fmul.d→fadd.d round-trip
# Construction: .rept 100, insn_per_iter=2
# ft0 = chain register, ft1=0.0 (fadd identity), ft2=1.0 (fmul identity)
    .global test_fadd_fmul
    .balign 4
test_fadd_fmul:
    mv   t3, a0
.L_fadd_fmul_loop:
    beqz t3, .L_fadd_fmul_done
    .rept 100
    fadd.d  ft0, ft0, ft1
    fmul.d  ft0, ft0, ft2
    .endr
    addi t3, t3, -1
    j    .L_fadd_fmul_loop
.L_fadd_fmul_done:
    ret
