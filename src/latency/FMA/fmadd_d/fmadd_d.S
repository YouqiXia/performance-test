    .text

# --- FMADD.D ---
# FMADD.D self-chain, ft1=1.0 ft2=0.0 keeps value unchanged
# Construction: .rept 100, insn_per_iter=1
    .global test_fmadd_d
    .balign 4
test_fmadd_d:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
    li   t5, 0x3FF0000000000000
    fmv.d.x ft1, t5
    li   t5, 0x0000000000000000
    fmv.d.x ft2, t5
.L_fmadd_d_loop:
    beqz t3, .L_fmadd_d_done
    .rept 100
    fmadd.d ft0, ft0, ft1, ft2
    .endr
    addi t3, t3, -1
    j    .L_fmadd_d_loop
.L_fmadd_d_done:
    ret
