    .text

# --- FEQ.S ---
# FEQ.S + FMV.W.X roundtrip
# Construction: .rept 100, insn_per_iter=2
    .global test_feq_s
    .balign 4
test_feq_s:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3F800000
    fmv.w.x ft0, t5
    fmv.w.x ft1, t5
.L_feq_s_loop:
    beqz t3, .L_feq_s_done
    .rept 100
    feq.s t0, ft0, ft1
    fmv.w.x ft0, t0
    .endr
    addi t3, t3, -1
    j    .L_feq_s_loop
.L_feq_s_done:
    ret
