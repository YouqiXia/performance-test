    .text
    .global test_is_prime
    .balign 4
test_is_prime:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0
    li   s1, 0

    la   a0, .L_ip_nums
    li   a1, 0
    li   a2, 5

.L_ip_outer:
    beqz s0, .L_ip_done
    slli t0, a1, 2
    add  t0, a0, t0
    lw   a3, 0(t0)

    mv   t0, a3
    li   t1, 0

    li   t2, 3
    rem  t3, t0, t2
    add  t1, t1, t3
    li   t2, 5
    rem  t3, t0, t2
    add  t1, t1, t3
    li   t2, 7
    rem  t3, t0, t2
    add  t1, t1, t3
    li   t2, 11
    rem  t3, t0, t2
    add  t1, t1, t3
    li   t2, 13
    rem  t3, t0, t2
    add  t1, t1, t3
    li   t2, 17
    rem  t3, t0, t2
    add  t1, t1, t3
    li   t2, 19
    rem  t3, t0, t2
    add  t1, t1, t3
    li   t2, 23
    rem  t3, t0, t2
    add  t1, t1, t3

    beqz t1, .L_ip_not_prime
    li   t2, 29
    rem  t3, t0, t2
    bnez t3, .L_ip_is_prime

.L_ip_not_prime:
    li   a4, 0
    j    .L_ip_end
.L_ip_is_prime:
    li   a4, 1
.L_ip_end:
    add  s1, s1, a4

    addi a1, a1, 1
    blt  a1, a2, .L_ip_no_wrap
    li   a1, 0
.L_ip_no_wrap:
    addi s0, s0, -1
    j    .L_ip_outer

.L_ip_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret

.section .data
.align 4
.L_ip_nums:
    .word 1000003, 1000033, 1000037, 1000039, 1000081
