    .text

# --- FEQ.D ---
# FEQ.D + FMV.D.X roundtrip
# Construction: .rept 100, insn_per_iter=2
    .global test_feq_d
    .balign 4
test_feq_d:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
    fmv.d.x ft1, t5
.L_feq_d_loop:
    beqz t3, .L_feq_d_done
    .rept 100
    feq.d t0, ft0, ft1
    fmv.d.x ft0, t0
    .endr
    addi t3, t3, -1
    j    .L_feq_d_loop
.L_feq_d_done:
    ret
