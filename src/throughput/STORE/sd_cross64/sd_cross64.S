    .text

# --- SD cross 64B: Store dword crossing cacheline boundary ---
# Dispatch: STORE → MEM Pipe 0
# Base a1 is 64B-aligned; offsets 60/124/188/252 each place
# the 8-byte store across a 64B cacheline boundary.
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sd_cross64
    .balign 4
test_sd_cross64:
    mv   t3, a0
    li  a5, 0
.L_sd_cross64_loop:
    beqz t3, .L_sd_cross64_done
    .rept 25
    sd  a5, 60(a1)
    sd  a5, 124(a1)
    sd  a5, 188(a1)
    sd  a5, 252(a1)
    .endr
    addi t3, t3, -1
    j    .L_sd_cross64_loop
.L_sd_cross64_done:
    ret
