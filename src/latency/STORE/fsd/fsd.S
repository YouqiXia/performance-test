    .text

# --- FSD ---
# FSD+FLD roundtrip, FP store-to-load forwarding latency
# Construction: .rept 50, insn_per_iter=2
    .global test_fsd
    .balign 4
test_fsd:
    mv   t3, a0
    # Initialize registers
    li   t5, 0x3FF0000000000000
    fmv.d.x ft0, t5
.L_fsd_loop:
    beqz t3, .L_fsd_done
    .rept 50
    fsd  ft0, 0(a1)
    fld  ft0, 0(a1)
    .endr
    addi t3, t3, -1
    j    .L_fsd_loop
.L_fsd_done:
    ret
