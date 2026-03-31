    .text

# --- FADD.D ---
# FADD.D self-chain, ft1=0.0 keeps value unchanged
# Construction: .rept 100, insn_per_iter=1
    .global test_fadd_d
    .balign 4
test_fadd_d:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
    li   t5, 0x0000000000000000
    fmv.d.x ft1, t5
.L_fadd_d_loop:
    beqz t3, .L_fadd_d_done
    .rept 100
    fadd.d  ft0, ft0, ft1
    .endr
    addi t3, t3, -1
    j    .L_fadd_d_loop
.L_fadd_d_done:
    ret
