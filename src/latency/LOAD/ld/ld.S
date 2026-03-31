    .text

# --- LD ---
# LD pointer-chase self-loop, L1 hit latency
# Construction: .rept 100, insn_per_iter=1
    .global test_ld
    .balign 4
test_ld:
    mv   t3, a0
    # Initialize registers
    mv   t0, a1
.L_ld_loop:
    beqz t3, .L_ld_done
    .rept 100
    ld   t0, 0(t0)
    .endr
    addi t3, t3, -1
    j    .L_ld_loop
.L_ld_done:
    ret
