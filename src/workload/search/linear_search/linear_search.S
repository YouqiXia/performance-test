    .text
    .global test_linear_search
    .balign 4
test_linear_search:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0            # nloop
    li   s1, 0             # result

.L_ls_outer:
    beqz s0, .L_ls_done
    la   t0, .L_ls_array
    li   t1, 0             # index
    li   a2, 42            # target
    li   t2, -1            # result = not found

.L_ls_scan:
    li   a1, 10
    bge  t1, a1, .L_ls_end
    lw   t3, 0(t0)
    beq  t3, a2, .L_ls_found
    addi t0, t0, 4
    addi t1, t1, 1
    j    .L_ls_scan

.L_ls_found:
    mv   t2, t1
.L_ls_end:
    add  s1, s1, t2
    addi s0, s0, -1
    j    .L_ls_outer

.L_ls_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret

.section .data
.align 4
.L_ls_array:
    .word 1, 3, 7, 14, 25, 42, 63, 89, 102, 127
