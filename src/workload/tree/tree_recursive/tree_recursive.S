    .text
    .global test_tree_recursive
    .balign 4
test_tree_recursive:
    addi sp, sp, -24
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    sd   ra, 16(sp)
    mv   s0, a0
    la   s1, .L_tr_result

.L_tr_outer:
    beqz s0, .L_tr_done
    mv   a1, s1
    la   t0, .L_tr_root
    ld   a0, 0(t0)
    jal  ra, .L_tr_inorder
    addi s0, s0, -1
    j    .L_tr_outer

.L_tr_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    ld   ra, 16(sp)
    addi sp, sp, 24
    ret

.L_tr_inorder:
    beqz a0, .L_tr_end
    addi sp, sp, -16
    sd   ra, 8(sp)
    sd   a0, 0(sp)
    ld   a0, 8(a0)
    jal  ra, .L_tr_inorder
    ld   t0, 0(sp)
    ld   t1, 0(t0)
    sd   t1, 0(a1)
    addi a1, a1, 8
    ld   a0, 16(t0)
    jal  ra, .L_tr_inorder
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret
.L_tr_end:
    ret

.section .data
.align 3
.L_tr_node1: .dword 1, .L_tr_node2, .L_tr_node3
.L_tr_node2: .dword 2, 0, 0
.L_tr_node3: .dword 3, .L_tr_node4, 0
.L_tr_node4: .dword 4, 0, 0
.L_tr_root:  .dword .L_tr_node1
.L_tr_result: .fill 20, 8, 0
