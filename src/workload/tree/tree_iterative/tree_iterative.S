    .text
    .global test_tree_iterative
    .balign 4
test_tree_iterative:
    addi sp, sp, -24
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    sd   ra, 16(sp)
    mv   s0, a0
    la   s1, .L_ti_result

.L_ti_outer:
    beqz s0, .L_ti_done
    mv   a1, s1
    la   t0, .L_ti_root
    ld   a0, 0(t0)
    jal  ra, .L_ti_inorder
    addi s0, s0, -1
    j    .L_ti_outer

.L_ti_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    ld   ra, 16(sp)
    addi sp, sp, 24
    ret

.L_ti_inorder:
    beqz a0, .L_ti_end
    addi sp, sp, -160
    li   t1, 0
    mv   t0, a0
.L_ti_push_left:
    beqz t0, .L_ti_process
    sd   t0, 0(sp)
    addi sp, sp, 8
    addi t1, t1, 1
    ld   t0, 8(t0)
    j    .L_ti_push_left
.L_ti_process:
    beqz t1, .L_ti_end_iter
    addi sp, sp, -8
    addi t1, t1, -1
    ld   t0, 0(sp)
    ld   t2, 0(t0)
    sd   t2, 0(a1)
    addi a1, a1, 8
    ld   t0, 16(t0)
    j    .L_ti_push_left
.L_ti_end_iter:
    addi sp, sp, 160
.L_ti_end:
    ret

.section .data
.align 3
.L_ti_node1: .dword 1, .L_ti_node2, .L_ti_node3
.L_ti_node2: .dword 2, 0, 0
.L_ti_node3: .dword 3, .L_ti_node4, 0
.L_ti_node4: .dword 4, 0, 0
.L_ti_root:  .dword .L_ti_node1
.L_ti_result: .fill 20, 8, 0
