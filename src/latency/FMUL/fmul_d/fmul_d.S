    .text

# --- FMUL.D ---
# FMUL.D self-chain, ft1=1.0 keeps value unchanged
# Construction: .rept 100, insn_per_iter=1
    .global test_fmul_d
    .balign 4
test_fmul_d:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
    li   t5, 0x3FF0000000000000
    fmv.d.x ft1, t5
.L_fmul_d_loop:
    beqz t3, .L_fmul_d_done
    .rept 100
    fmul.d  ft0, ft0, ft1
    .endr
    addi t3, t3, -1
    j    .L_fmul_d_loop
.L_fmul_d_done:
    ret
