    .text
    .global test_dot_product
    .balign 4
test_dot_product:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0
    li   s1, 0

.L_dp_outer:
    beqz s0, .L_dp_done
    la   t0, .L_dp_a
    la   t1, .L_dp_b
    li   t3, 16            # 64/4 = 16 iterations
    li   s2, 0             # sum

.L_dp_inner:
    lw   t4, 0(t0)
    lw   t5, 0(t1)
    mul  t6, t4, t5
    add  s2, s2, t6
    lw   t4, 4(t0)
    lw   t5, 4(t1)
    mul  t6, t4, t5
    add  s2, s2, t6
    lw   t4, 8(t0)
    lw   t5, 8(t1)
    mul  t6, t4, t5
    add  s2, s2, t6
    lw   t4, 12(t0)
    lw   t5, 12(t1)
    mul  t6, t4, t5
    add  s2, s2, t6
    addi t0, t0, 16
    addi t1, t1, 16
    addi t3, t3, -1
    bnez t3, .L_dp_inner

    add  s1, s1, s2
    addi s0, s0, -1
    j    .L_dp_outer

.L_dp_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret

.section .data
.align 4
.L_dp_a:
    .word 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16
    .word 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32
    .word 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48
    .word 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64
.L_dp_b:
    .word 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
    .word 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2
    .word 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3
    .word 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4
