    .text
    .global test_power_naive
    .balign 4
test_power_naive:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0
    li   s1, 0

    la   a0, .L_pn_cases
    li   a1, 0
    li   a2, 5

.L_pn_outer:
    beqz s0, .L_pn_done
    slli t0, a1, 3
    add  t0, a0, t0
    lw   a3, 0(t0)         # base
    lw   a4, 4(t0)         # exp

    li   a5, 1
    beqz a4, .L_pn_iter_done
    li   t0, 0
.L_pn_loop:
    bge  t0, a4, .L_pn_iter_done
    mul  a5, a5, a3
    addi t0, t0, 1
    j    .L_pn_loop

.L_pn_iter_done:
    add  s1, s1, a5

    addi a1, a1, 1
    blt  a1, a2, .L_pn_no_wrap
    li   a1, 0
.L_pn_no_wrap:
    addi s0, s0, -1
    j    .L_pn_outer

.L_pn_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret

.section .data
.align 4
.L_pn_cases:
    .word 2, 5
    .word 3, 4
    .word 5, 3
    .word 7, 3
    .word 11, 2
