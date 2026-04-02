    .text
    .global test_gcd
    .balign 4
test_gcd:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0
    li   s1, 0

    la   a0, .L_gcd_data
    li   a1, 0
    li   a2, 4

.L_gcd_outer:
    beqz s0, .L_gcd_done
    slli t0, a1, 3
    add  t0, a0, t0
    lw   a3, 0(t0)
    lw   a4, 4(t0)

    li   t1, 0
    mv   t2, a3
    mv   t3, a4

.L_gcd_heavy:
    rem  t4, t2, t3
    rem  t5, t3, t4
    rem  t6, t4, t5
    rem  t2, t5, t6
    mv   t3, t6
    addi t1, t1, 1
    li   t5, 5
    blt  t1, t5, .L_gcd_heavy

    beqz t3, .L_gcd_eucl_done
.L_gcd_eucl:
    rem  t0, t2, t3
    mv   t2, t3
    mv   t3, t0
    bnez t3, .L_gcd_eucl
.L_gcd_eucl_done:

    add  s1, s1, t2
    addi a1, a1, 1
    blt  a1, a2, .L_gcd_no_wrap
    li   a1, 0
.L_gcd_no_wrap:
    addi s0, s0, -1
    j    .L_gcd_outer

.L_gcd_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret

.section .data
.align 4
.L_gcd_data:
    .word 123456789, 987654321
    .word 100007, 100009
    .word 2147483647, 2147483629
    .word 123456, 789012
