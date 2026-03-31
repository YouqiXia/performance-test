    .text

# --- FDIV↔FADD forwarding chain ---
# fdiv.d→fadd.d→fdiv.d round-trip
# Construction: .rept 20, insn_per_iter=2
# ft0 = chain register, ft1=1.0 (fdiv identity), ft2=0.0 (fadd identity)
# .rept=20 because FDIV is very slow
    .global test_fdiv_fadd
    .balign 4
test_fdiv_fadd:
    mv   t3, a0
.L_fdiv_fadd_loop:
    beqz t3, .L_fdiv_fadd_done
    .rept 20
    fdiv.d  ft0, ft0, ft1
    fadd.d  ft0, ft0, ft2
    .endr
    addi t3, t3, -1
    j    .L_fdiv_fadd_loop
.L_fdiv_fadd_done:
    ret
