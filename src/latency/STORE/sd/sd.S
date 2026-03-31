    .text

# --- SD ---
# SD+LD roundtrip, INT store-to-load forwarding latency
# Construction: .rept 50, insn_per_iter=2
    .global test_sd
    .balign 4
test_sd:
    mv   t3, a0
    # Initialize registers
    li   t0, 42
.L_sd_loop:
    beqz t3, .L_sd_done
    .rept 50
    sd   t0, 0(a1)
    ld   t0, 0(a1)
    .endr
    addi t3, t3, -1
    j    .L_sd_loop
.L_sd_done:
    ret
