    .text

# --- AMOADD.W ---
# AMOADD.W serial, atomic RMW latency
# Construction: .rept 20, insn_per_iter=1
    .global test_amoadd_w
    .balign 4
test_amoadd_w:
    mv   t3, a0
    # Initialize registers
    li   t0, 0
.L_amoadd_w_loop:
    beqz t3, .L_amoadd_w_done
    .rept 20
    amoadd.w t0, t0, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amoadd_w_loop
.L_amoadd_w_done:
    ret
