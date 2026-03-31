    .text

# --- FADD.S ---
# FADD.S self-chain, ft1=0.0 keeps value unchanged
# Construction: .rept 100, insn_per_iter=1
    .global test_fadd_s
    .balign 4
test_fadd_s:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3F800000
    fmv.w.x ft0, t5
    li   t5, 0x00000000
    fmv.w.x ft1, t5
.L_fadd_s_loop:
    beqz t3, .L_fadd_s_done
    .rept 100
    fadd.s  ft0, ft0, ft1
    .endr
    addi t3, t3, -1
    j    .L_fadd_s_loop
.L_fadd_s_done:
    ret
