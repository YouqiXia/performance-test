    .text

# --- FMV.D.X ---
# FMV.D.X + FMV.X.D roundtrip
# Construction: .rept 100, insn_per_iter=2
    .global test_fmv_d_x
    .balign 4
test_fmv_d_x:
    mv   t3, a0
    # Initialize registers
    li   t0, 0x3FF0000000000000
.L_fmv_d_x_loop:
    beqz t3, .L_fmv_d_x_done
    .rept 100
    fmv.d.x ft0, t0
    fmv.x.d t0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fmv_d_x_loop
.L_fmv_d_x_done:
    ret
