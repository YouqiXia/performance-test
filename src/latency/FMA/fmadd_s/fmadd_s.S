    .text

# --- FMADD.S ---
# FMADD.S self-chain, ft1=1.0 ft2=0.0 keeps value unchanged
# Construction: .rept 100, insn_per_iter=1
    .global test_fmadd_s
    .balign 4
test_fmadd_s:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3F800000
    fmv.w.x ft0, t5
    li   t5, 0x3F800000
    fmv.w.x ft1, t5
    li   t5, 0x00000000
    fmv.w.x ft2, t5
.L_fmadd_s_loop:
    beqz t3, .L_fmadd_s_done
    .rept 100
    fmadd.s ft0, ft0, ft1, ft2
    .endr
    addi t3, t3, -1
    j    .L_fmadd_s_loop
.L_fmadd_s_done:
    ret
