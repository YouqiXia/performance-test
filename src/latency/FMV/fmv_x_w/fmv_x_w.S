    .text

# --- FMV.X.W ---
# FMV.X.W + FMV.W.X roundtrip
# Construction: .rept 100, insn_per_iter=2
    .global test_fmv_x_w
    .balign 4
test_fmv_x_w:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3F800000
    fmv.w.x ft0, t5
.L_fmv_x_w_loop:
    beqz t3, .L_fmv_x_w_done
    .rept 100
    fmv.x.w t0, ft0
    fmv.w.x ft0, t0
    .endr
    addi t3, t3, -1
    j    .L_fmv_x_w_loop
.L_fmv_x_w_done:
    ret
