    .text
    .global test_bfs
    .balign 4
test_bfs:
    addi sp, sp, -24
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    sd   s2, 16(sp)
    mv   s2, a0

.L_bfs_loop:
    beqz s2, .L_bfs_done

    # Reset visited
    la   t0, .L_bfs_visited
    sd   zero, 0(t0)

    # Init queue: enqueue vertex 0
    la   t0, .L_bfs_queue
    sd   zero, 0(t0)
    la   t1, .L_bfs_qend
    li   t2, 8
    sw   t2, 0(t1)
    la   t1, .L_bfs_qstart
    sw   zero, 0(t1)

    # Mark vertex 0 visited
    la   t3, .L_bfs_visited
    li   t4, 1
    sb   t4, 0(t3)

.L_bfs_main:
    la   t0, .L_bfs_qstart
    lw   t1, 0(t0)
    la   t2, .L_bfs_qend
    lw   t3, 0(t2)
    beq  t1, t3, .L_bfs_complete

    # Dequeue
    la   t4, .L_bfs_queue
    add  t5, t4, t1
    ld   s0, 0(t5)
    addi t1, t1, 8
    la   t0, .L_bfs_qstart
    sw   t1, 0(t0)

    # Traverse neighbors
    li   s1, 0
.L_bfs_neigh:
    li   t6, 5
    beq  s1, t6, .L_bfs_next

    la   t0, .L_bfs_graph
    li   t1, 5
    mul  t2, s0, t1
    add  t2, t2, s1
    add  t0, t0, t2
    lb   t3, 0(t0)
    beqz t3, .L_bfs_neigh_next

    la   t0, .L_bfs_visited
    add  t1, t0, s1
    lb   t2, 0(t1)
    bnez t2, .L_bfs_neigh_next

    li   t3, 1
    sb   t3, 0(t1)

    la   t0, .L_bfs_queue
    la   t1, .L_bfs_qend
    lw   t2, 0(t1)
    add  t3, t0, t2
    sd   s1, 0(t3)
    addi t2, t2, 8
    sw   t2, 0(t1)

.L_bfs_neigh_next:
    addi s1, s1, 1
    j    .L_bfs_neigh

.L_bfs_next:
    j    .L_bfs_main

.L_bfs_complete:
    addi s2, s2, -1
    j    .L_bfs_loop

.L_bfs_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    ld   s2, 16(sp)
    addi sp, sp, 24
    ret

.section .data
.align 3
.L_bfs_graph:    .byte 0,1,1,0,0,1,0,1,1,0,1,1,0,0,1,0,1,0,0,1,0,0,1,1,0
.align 3
.L_bfs_visited:  .zero 8
.align 3
.L_bfs_queue:    .zero 40
.align 3
.L_bfs_qstart:  .word 0
.L_bfs_qend:    .word 0
