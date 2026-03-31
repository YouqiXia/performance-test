    .text

# --- CLZ ---
# BMU clz self-chain, clz(58)=58 is a fixed point
# Construction: .rept 100, insn_per_iter=1
    .global test_clz
    .balign 4
test_clz:
    mv   t3, a0
    # Initialize registers
    li   t0, 58
.L_clz_loop:
    beqz t3, .L_clz_done
    .rept 100
    clz  t0, t0
    .endr
    addi t3, t3, -1
    j    .L_clz_loop
.L_clz_done:
    ret
