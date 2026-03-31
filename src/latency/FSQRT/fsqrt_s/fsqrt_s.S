    .text

# --- FSQRT.S ---
# FSQRT.S self-chain, sqrt(1.0)=1.0 stable
# Construction: .rept 20, insn_per_iter=1
    .global test_fsqrt_s
    .balign 4
test_fsqrt_s:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3F800000
    fmv.w.x ft0, t5
.L_fsqrt_s_loop:
    beqz t3, .L_fsqrt_s_done
    .rept 20
    fsqrt.s ft0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fsqrt_s_loop
.L_fsqrt_s_done:
    ret
