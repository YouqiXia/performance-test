    .text
    .global test_tree_search
    .balign 4
test_tree_search:
    addi sp, sp, -24
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    sd   ra, 16(sp)
    mv   s0, a0

    la   s1, .L_ts_root
    ld   s1, 0(s1)

.L_ts_outer:
    beqz s0, .L_ts_done
    mv   a0, s1
    li   a1, 3
    jal  ra, .L_ts_search
    addi s0, s0, -1
    j    .L_ts_outer

.L_ts_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    ld   ra, 16(sp)
    addi sp, sp, 24
    ret

.L_ts_search:
    addi sp, sp, -16
    sd   ra, 0(sp)
    sd   s0, 8(sp)
    mv   s0, a0
    li   a0, 0
.L_ts_loop:
    beqz s0, .L_ts_end
    ld   t0, 0(s0)
    beq  t0, a1, .L_ts_found
    blt  a1, t0, .L_ts_left
    ld   s0, 16(s0)
    j    .L_ts_loop
.L_ts_left:
    ld   s0, 8(s0)
    j    .L_ts_loop
.L_ts_found:
    mv   a0, s0
.L_ts_end:
    ld   ra, 0(sp)
    ld   s0, 8(sp)
    addi sp, sp, 16
    ret

.section .data
.align 3
.L_ts_node1: .dword 1, .L_ts_node2, .L_ts_node3
.L_ts_node2: .dword 2, 0, 0
.L_ts_node3: .dword 3, .L_ts_node4, 0
.L_ts_node4: .dword 4, 0, 0
.L_ts_root:  .dword .L_ts_node1
