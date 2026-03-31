    .text

# --- FDIV.S ---
# FDIV.S self-chain, ft1=1.0 keeps value unchanged
# Construction: .rept 20, insn_per_iter=1
    .global test_fdiv_s
    .balign 4
test_fdiv_s:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3F800000
    fmv.w.x ft0, t5
    li   t5, 0x3F800000
    fmv.w.x ft1, t5
.L_fdiv_s_loop:
    beqz t3, .L_fdiv_s_done
    .rept 20
    fdiv.s  ft0, ft0, ft1
    .endr
    addi t3, t3, -1
    j    .L_fdiv_s_loop
.L_fdiv_s_done:
    ret
