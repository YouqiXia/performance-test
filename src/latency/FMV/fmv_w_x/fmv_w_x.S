    .text

# --- FMV.W.X ---
# FMV.W.X + FMV.X.W roundtrip
# Construction: .rept 100, insn_per_iter=2
    .global test_fmv_w_x
    .balign 4
test_fmv_w_x:
    mv   t3, a0
    # Initialize registers
    li   t0, 0x3F800000
.L_fmv_w_x_loop:
    beqz t3, .L_fmv_w_x_done
    .rept 100
    fmv.w.x ft0, t0
    fmv.x.w t0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fmv_w_x_loop
.L_fmv_w_x_done:
    ret
