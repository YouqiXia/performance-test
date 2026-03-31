    .text

# --- FSQRT↔FADD forwarding chain ---
# fsqrt.d→fadd.d→fsqrt.d round-trip
# Construction: .rept 20, insn_per_iter=2
# ft0 = chain register (init 1.0, sqrt(1)=1), ft1=0.0 (fadd identity)
    .global test_fsqrt_fadd
    .balign 4
test_fsqrt_fadd:
    mv   t3, a0
.L_fsqrt_fadd_loop:
    beqz t3, .L_fsqrt_fadd_done
    .rept 20
    fsqrt.d ft0, ft0
    fadd.d  ft0, ft0, ft1
    .endr
    addi t3, t3, -1
    j    .L_fsqrt_fadd_loop
.L_fsqrt_fadd_done:
    ret
