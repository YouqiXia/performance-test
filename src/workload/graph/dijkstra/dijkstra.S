    .text
    .global test_dijkstra
    .balign 4
test_dijkstra:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   ra, 8(sp)
    mv   s0, a0

.L_dj_outer:
    beqz s0, .L_dj_done
    li   a0, 0
    jal  ra, .L_dj_dijkstra
    addi s0, s0, -1
    j    .L_dj_outer

.L_dj_done:
    ld   s0, 0(sp)
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

.equ DJ_INF, 0x7FFFFFFF
.equ DJ_V, 5

.L_dj_dijkstra:
    addi sp, sp, -16
    sd   ra, 8(sp)
    sd   s0, 0(sp)

    jal  ra, .L_dj_init

    li   s1, 0
.L_dj_ol:
    li   t0, DJ_V
    bge  s1, t0, .L_dj_ol_done

    li   a0, -1
    li   a1, DJ_INF
    li   s3, 0
.L_dj_find_min:
    li   t0, DJ_V
    bge  s3, t0, .L_dj_find_done
    la   t0, .L_dj_vis
    add  t1, t0, s3
    lb   t2, 0(t1)
    bnez t2, .L_dj_find_next
    la   t0, .L_dj_dist
    slli t1, s3, 3
    add  t0, t0, t1
    lw   t3, 0(t0)
    bge  t3, a1, .L_dj_find_next
    mv   a0, s3
    mv   a1, t3
.L_dj_find_next:
    addi s3, s3, 1
    j    .L_dj_find_min
.L_dj_find_done:

    bltz a0, .L_dj_ol_done
    la   t0, .L_dj_vis
    add  t1, t0, a0
    li   t2, 1
    sb   t2, 0(t1)

    mv   s0, a0
    li   s3, 0
.L_dj_update:
    li   t0, DJ_V
    bge  s3, t0, .L_dj_update_done
    la   t0, .L_dj_vis
    add  t1, t0, s3
    lb   t2, 0(t1)
    bnez t2, .L_dj_update_next

    mv   a0, s0
    mv   a1, s3
    jal  ra, .L_dj_get_weight
    beqz a0, .L_dj_update_next

    la   t0, .L_dj_dist
    slli t1, s0, 3
    add  t0, t0, t1
    lw   t1, 0(t0)
    add  t2, t1, a0

    la   t0, .L_dj_dist
    slli t1, s3, 3
    add  t0, t0, t1
    lw   t3, 0(t0)
    bge  t2, t3, .L_dj_update_next
    sw   t2, 0(t0)

.L_dj_update_next:
    addi s3, s3, 1
    j    .L_dj_update
.L_dj_update_done:
    addi s1, s1, 1
    j    .L_dj_ol
.L_dj_ol_done:

    ld   ra, 8(sp)
    ld   s0, 0(sp)
    addi sp, sp, 16
    ret

.L_dj_init:
    li   t0, 0
    li   t1, DJ_V
    la   t2, .L_dj_dist
    la   t3, .L_dj_vis
    li   t5, DJ_INF
.L_dj_init_loop:
    bge  t0, t1, .L_dj_init_done
    bnez t0, .L_dj_not_src
    sw   zero, 0(t2)
    j    .L_dj_set_vis
.L_dj_not_src:
    sw   t5, 0(t2)
.L_dj_set_vis:
    sb   zero, 0(t3)
    addi t2, t2, 8
    addi t3, t3, 1
    addi t0, t0, 1
    j    .L_dj_init_loop
.L_dj_init_done:
    ret

.L_dj_get_weight:
    la   t0, .L_dj_wmat
    li   t1, DJ_V
    mul  t2, a0, t1
    add  t2, t2, a1
    slli t2, t2, 2
    add  t0, t0, t2
    lw   a0, 0(t0)
    ret

.section .data
.align 3
.L_dj_wmat:
    .word 0, 7, 9, 0, 0
    .word 7, 0, 10, 15, 0
    .word 9, 10, 0, 11, 2
    .word 0, 15, 11, 0, 6
    .word 0, 0, 2, 6, 0
.align 3
.L_dj_dist:  .zero 40
.align 3
.L_dj_vis:   .zero 8
