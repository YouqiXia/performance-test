    .text

# --- FROUND.S ---
# FROUND.S self-chain, round(1.0)=1.0 stable
# Construction: .rept 100, insn_per_iter=1
    .global test_fround_s
    .balign 4
test_fround_s:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3F800000
    fmv.w.x ft0, t5
.L_fround_s_loop:
    beqz t3, .L_fround_s_done
    .rept 100
    fround.s ft0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fround_s_loop
.L_fround_s_done:
    ret
