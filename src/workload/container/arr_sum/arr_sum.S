    .text
    .global test_arr_sum
    .balign 4
test_arr_sum:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0            # s0 = nloop
    li   s1, 0             # result accumulator

.L_as_outer:
    beqz s0, .L_as_done
    la   a2, .L_as_array   # array base
    li   a3, 0             # index
    li   a4, 0             # sum

.L_as_inner:
    li   t0, 10
    bge  a3, t0, .L_as_iter_done
    slli t0, a3, 2
    add  t1, a2, t0
    lw   t2, 0(t1)
    add  a4, a4, t2
    addi a3, a3, 1
    j    .L_as_inner

.L_as_iter_done:
    add  s1, s1, a4
    addi s0, s0, -1
    j    .L_as_outer

.L_as_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret

.section .data
.align 4
.L_as_array:
    .word 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
