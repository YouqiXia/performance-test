    .text
    .global test_fib_recursive
    .balign 4
test_fib_recursive:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   ra, 8(sp)
    mv   s0, a0

.L_fr_outer:
    beqz s0, .L_fr_done
    li   a0, 10
    jal  ra, .L_fr_fib
    addi s0, s0, -1
    j    .L_fr_outer

.L_fr_done:
    ld   s0, 0(sp)
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

.L_fr_fib:
    addi sp, sp, -16
    sd   ra, 8(sp)
    sd   a0, 0(sp)
    li   t0, 1
    ble  a0, t0, .L_fr_base
    addi a0, a0, -1
    jal  ra, .L_fr_fib
    mv   t1, a0
    ld   a0, 0(sp)
    addi a0, a0, -2
    jal  ra, .L_fr_fib
    add  a0, t1, a0
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret
.L_fr_base:
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret
