    .text

# --- SD↔LD INT store forwarding ---
# sd→ld round-trip via store buffer forwarding
# Construction: .rept 100, insn_per_iter=2
# t0 = chain register, a1 = fixed memory address
    .global test_sd_ld
    .balign 4
test_sd_ld:
    mv   t3, a0
    # a1 = buffer address (passed by caller)
.L_sd_ld_loop:
    beqz t3, .L_sd_ld_done
    .rept 100
    sd   t0, 0(a1)
    ld   t0, 0(a1)
    .endr
    addi t3, t3, -1
    j    .L_sd_ld_loop
.L_sd_ld_done:
    ret
