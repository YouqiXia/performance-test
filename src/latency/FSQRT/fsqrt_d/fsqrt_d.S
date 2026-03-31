    .text

# --- FSQRT.D ---
# FSQRT.D self-chain, sqrt(1.0)=1.0 stable
# Construction: .rept 20, insn_per_iter=1
    .global test_fsqrt_d
    .balign 4
test_fsqrt_d:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
.L_fsqrt_d_loop:
    beqz t3, .L_fsqrt_d_done
    .rept 20
    fsqrt.d ft0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fsqrt_d_loop
.L_fsqrt_d_done:
    ret
