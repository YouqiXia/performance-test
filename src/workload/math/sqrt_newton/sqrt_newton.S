    .text
    .global test_sqrt_newton
    .balign 4
test_sqrt_newton:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0

    la   a0, .L_sn_values
    li   a1, 0
    li   a2, 4

    la   t0, .L_sn_consts
    fld  fs2, 0(t0)        # epsilon = 1e-12
    fld  fs3, 8(t0)        # 2.0
    fld  fs4, 16(t0)       # 0.5
    fld  fs5, 24(t0)       # 1.0
    fmv.d.x fs1, zero      # accumulator

.L_sn_outer:
    beqz s0, .L_sn_done
    slli t0, a1, 3
    add  t0, a0, t0
    fld  fa0, 0(t0)

    li   t0, 0
    fmv.d fa1, fa0         # initial guess

.L_sn_inner:
    fmul.d ft0, fa1, fa1
    fsub.d ft0, ft0, fa0
    fsgnjx.d ft0, ft0, ft0 # abs
    fle.d  t1, ft0, fs2
    bnez t1, .L_sn_converged
    fdiv.d ft1, fa0, fa1
    fadd.d ft2, fa1, ft1
    fdiv.d fa1, ft2, fs3
    fmul.d ft3, fa1, fs4
    fadd.d ft4, fa1, fs5
    fdiv.d ft5, ft3, ft4
    addi t0, t0, 1
    li   t1, 100
    blt  t0, t1, .L_sn_inner

.L_sn_converged:
    fadd.d fs1, fs1, fa1

    addi a1, a1, 1
    blt  a1, a2, .L_sn_no_wrap
    li   a1, 0
.L_sn_no_wrap:
    addi s0, s0, -1
    j    .L_sn_outer

.L_sn_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret

.section .data
.align 3
.L_sn_values:
    .double 1.0, 10.0, 100.0, 1000.0
.L_sn_consts:
    .double 1e-12
    .double 2.0
    .double 0.5
    .double 1.0
    .double 0.0
