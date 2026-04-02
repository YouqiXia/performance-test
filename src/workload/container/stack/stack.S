    .text
    .global test_stack
    .balign 4
test_stack:
    addi sp, sp, -32
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    sd   s2, 16(sp)
    sd   s3, 24(sp)
    mv   s0, a0            # s0 = nloop
    li   s1, 0             # result accumulator
    li   s2, 1             # push value

    la   a0, .L_stk_data
    sw   zero, 64(a0)      # top = 0

.L_stk_outer:
    beqz s0, .L_stk_done
    li   s3, 16            # inner loop count

.L_stk_inner:
    beqz s3, .L_stk_iter_done

    # Push
    lw   t0, 64(a0)
    slli t1, t0, 2
    add  t2, a0, t1
    sw   s2, 0(t2)
    addi t0, t0, 1
    sw   t0, 64(a0)
    addi s2, s2, 1

    # Pop
    lw   t0, 64(a0)
    addi t0, t0, -1
    sw   t0, 64(a0)
    slli t1, t0, 2
    add  t2, a0, t1
    lw   t3, 0(t2)
    add  s1, s1, t3

    addi s3, s3, -1
    j    .L_stk_inner

.L_stk_iter_done:
    addi s0, s0, -1
    j    .L_stk_outer

.L_stk_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    ld   s2, 16(sp)
    ld   s3, 24(sp)
    addi sp, sp, 32
    ret

.section .data
.align 4
.L_stk_data:
    .space 64               # data[16]
    .word 0                 # top (offset 64)
