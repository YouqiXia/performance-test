    .text

# --- FSGNJ.D ---
# FSGNJ.D self-chain, ft1=+1.0 keeps sign positive
# Construction: .rept 100, insn_per_iter=1
    .global test_fsgnj_d
    .balign 4
test_fsgnj_d:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
    li   t5, 0x3FF0000000000000
    fmv.d.x ft1, t5
.L_fsgnj_d_loop:
    beqz t3, .L_fsgnj_d_done
    .rept 100
    fsgnj.d ft0, ft0, ft1
    .endr
    addi t3, t3, -1
    j    .L_fsgnj_d_loop
.L_fsgnj_d_done:
    ret
