    .text

# --- FDIV.D ---
# FDIV.D self-chain, ft1=1.0 keeps value unchanged
# Construction: .rept 20, insn_per_iter=1
    .global test_fdiv_d
    .balign 4
test_fdiv_d:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
    li   t5, 0x3FF0000000000000
    fmv.d.x ft1, t5
.L_fdiv_d_loop:
    beqz t3, .L_fdiv_d_done
    .rept 20
    fdiv.d  ft0, ft0, ft1
    .endr
    addi t3, t3, -1
    j    .L_fdiv_d_loop
.L_fdiv_d_done:
    ret
