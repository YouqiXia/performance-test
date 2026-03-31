    .text

# --- FROUND.D ---
# FROUND.D self-chain, round(1.0)=1.0 stable
# Construction: .rept 100, insn_per_iter=1
    .global test_fround_d
    .balign 4
test_fround_d:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
.L_fround_d_loop:
    beqz t3, .L_fround_d_done
    .rept 100
    fround.d ft0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fround_d_loop
.L_fround_d_done:
    ret
