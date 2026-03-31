    .text

# --- FDIV↔FMA forwarding chain ---
# fdiv.d→fmadd.d→fdiv.d round-trip
# Construction: .rept 20, insn_per_iter=2
# ft0 = chain register, ft1=1.0 (div identity), ft2=1.0, ft3=0.0 (fma: ft0*1+0=ft0)
    .global test_fdiv_fma
    .balign 4
test_fdiv_fma:
    mv   t3, a0
.L_fdiv_fma_loop:
    beqz t3, .L_fdiv_fma_done
    .rept 20
    fdiv.d   ft0, ft0, ft1
    fmadd.d  ft0, ft0, ft2, ft3
    .endr
    addi t3, t3, -1
    j    .L_fdiv_fma_loop
.L_fdiv_fma_done:
    ret
