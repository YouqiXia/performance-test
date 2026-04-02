    .text
    .global test_tree_heap
    .balign 4
test_tree_heap:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   ra, 8(sp)
    mv   s0, a0

.L_th_outer:
    beqz s0, .L_th_done
    la   a0, .L_th_heap
    li   a1, 0
    la   s2, .L_th_vals
    li   s3, 5
    li   t0, 0
.L_th_ins:
    bge  t0, s3, .L_th_ins_done
    slli t1, t0, 3
    add  t1, s2, t1
    ld   a2, 0(t1)
    addi sp, sp, -8
    sd   t0, 0(sp)
    jal  ra, .L_th_insert
    ld   t0, 0(sp)
    addi sp, sp, 8
    addi t0, t0, 1
    j    .L_th_ins
.L_th_ins_done:
    addi s0, s0, -1
    j    .L_th_outer

.L_th_done:
    ld   s0, 0(sp)
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

.L_th_insert:
    li   t0, 20
    bge  a1, t0, .L_th_ret
    slli t1, a1, 3
    add  t2, a0, t1
    sd   a2, 0(t2)
    addi a1, a1, 1
    addi t3, a1, -1
.L_th_sift:
    beqz t3, .L_th_ret
    addi t4, t3, -1
    srli t4, t4, 1
    slli t5, t3, 3
    add  t5, a0, t5
    ld   t5, 0(t5)
    slli t6, t4, 3
    add  t6, a0, t6
    ld   t6, 0(t6)
    bge  t6, t5, .L_th_ret
    # Swap
    slli t0, t3, 3
    add  t0, a0, t0
    slli t1, t4, 3
    add  t1, a0, t1
    ld   t2, 0(t0)
    ld   t3, 0(t1)
    sd   t2, 0(t1)
    sd   t3, 0(t0)
    mv   t3, t4
    j    .L_th_sift
.L_th_ret:
    ret

.section .data
.align 3
.L_th_heap: .fill 20, 8, 0
.L_th_vals:
    .dword 15, 8, 25, 3, 10
