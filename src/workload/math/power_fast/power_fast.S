    .text
    .global test_power_fast
    .balign 4
test_power_fast:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0
    li   s1, 0

.L_pf_outer:
    beqz s0, .L_pf_done
    li   a3, 2             # base
    li   a4, 16            # exp
    li   a5, 1             # result
    mv   a6, a3            # b

.L_pf_loop:
    beqz a4, .L_pf_iter_done
    andi t0, a4, 1
    beqz t0, .L_pf_skip
    mul  a5, a5, a6
.L_pf_skip:
    mul  a6, a6, a6
    srli a4, a4, 1
    j    .L_pf_loop

.L_pf_iter_done:
    add  s1, s1, a5
    addi s0, s0, -1
    j    .L_pf_outer

.L_pf_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
