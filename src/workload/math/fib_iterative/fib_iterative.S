    .text
    .global test_fib_iterative
    .balign 4
test_fib_iterative:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0
    li   s1, 0

.L_fi_outer:
    beqz s0, .L_fi_done
    li   a0, 20
    li   t0, 1
    ble  a0, t0, .L_fi_base
    li   t1, 0
    li   t2, 1
    li   t3, 2
    mv   t4, a0
.L_fi_loop:
    add  t0, t1, t2
    mv   t1, t2
    mv   t2, t0
    addi t3, t3, 1
    ble  t3, t4, .L_fi_loop
    mv   a0, t2
    j    .L_fi_end
.L_fi_base:
.L_fi_end:
    add  s1, s1, a0
    addi s0, s0, -1
    j    .L_fi_outer

.L_fi_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
