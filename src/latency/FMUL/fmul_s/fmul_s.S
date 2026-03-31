    .text

# --- FMUL.S ---
# FMUL.S self-chain, ft1=1.0 keeps value unchanged
# Construction: .rept 100, insn_per_iter=1
    .global test_fmul_s
    .balign 4
test_fmul_s:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3F800000
    fmv.w.x ft0, t5
    li   t5, 0x3F800000
    fmv.w.x ft1, t5
.L_fmul_s_loop:
    beqz t3, .L_fmul_s_done
    .rept 100
    fmul.s  ft0, ft0, ft1
    .endr
    addi t3, t3, -1
    j    .L_fmul_s_loop
.L_fmul_s_done:
    ret
