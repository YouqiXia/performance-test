    .text

# --- FMIN.S ---
# FMIN.S self-chain, ft1=100.0 so min always returns ft0
# Construction: .rept 100, insn_per_iter=1
    .global test_fmin_s
    .balign 4
test_fmin_s:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3F800000
    fmv.w.x ft0, t5
    li   t5, 0x42C80000
    fmv.w.x ft1, t5
.L_fmin_s_loop:
    beqz t3, .L_fmin_s_done
    .rept 100
    fmin.s  ft0, ft0, ft1
    .endr
    addi t3, t3, -1
    j    .L_fmin_s_loop
.L_fmin_s_done:
    ret
