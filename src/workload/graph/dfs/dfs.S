    .text
    .global test_dfs
    .balign 4
test_dfs:
    addi sp, sp, -24
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    sd   s2, 16(sp)
    mv   s2, a0

.L_dfs_loop:
    beqz s2, .L_dfs_done

    la   t0, .L_dfs_visited
    sd   zero, 0(t0)

    la   t0, .L_dfs_stack
    sd   zero, 0(t0)
    la   t1, .L_dfs_sptr
    li   t2, 8
    sw   t2, 0(t1)

    la   t3, .L_dfs_visited
    li   t4, 1
    sb   t4, 0(t3)

.L_dfs_main:
    la   t0, .L_dfs_sptr
    lw   t1, 0(t0)
    beqz t1, .L_dfs_complete

    la   t4, .L_dfs_stack
    addi t1, t1, -8
    sw   t1, 0(t0)
    add  t5, t4, t1
    ld   s0, 0(t5)

    li   s1, 0
.L_dfs_neigh:
    li   t6, 5
    beq  s1, t6, .L_dfs_next

    la   t0, .L_dfs_graph
    li   t1, 5
    mul  t2, s0, t1
    add  t2, t2, s1
    add  t0, t0, t2
    lb   t3, 0(t0)
    beqz t3, .L_dfs_neigh_next

    la   t0, .L_dfs_visited
    add  t1, t0, s1
    lb   t2, 0(t1)
    bnez t2, .L_dfs_neigh_next

    li   t3, 1
    sb   t3, 0(t1)

    # Push current back
    la   t0, .L_dfs_stack
    la   t1, .L_dfs_sptr
    lw   t2, 0(t1)
    add  t3, t0, t2
    sd   s0, 0(t3)
    addi t2, t2, 8
    sw   t2, 0(t1)

    # Push neighbor
    lw   t2, 0(t1)
    add  t3, t0, t2
    sd   s1, 0(t3)
    addi t2, t2, 8
    sw   t2, 0(t1)

    j    .L_dfs_main

.L_dfs_neigh_next:
    addi s1, s1, 1
    j    .L_dfs_neigh

.L_dfs_next:
    j    .L_dfs_main

.L_dfs_complete:
    addi s2, s2, -1
    j    .L_dfs_loop

.L_dfs_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    ld   s2, 16(sp)
    addi sp, sp, 24
    ret

.section .data
.align 3
.L_dfs_graph:    .byte 0,1,1,0,0,1,0,1,1,0,1,1,0,0,1,0,1,0,0,1,0,0,1,1,0
.align 3
.L_dfs_visited:  .zero 8
.align 3
.L_dfs_stack:    .zero 80
.align 3
.L_dfs_sptr:     .word 0
