    .text
    .global test_knapsack
    .balign 4
test_knapsack:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   ra, 8(sp)
    mv   s0, a0

.L_ks_outer:
    beqz s0, .L_ks_done
    la   a0, .L_ks_weights
    la   a1, .L_ks_values
    li   a2, 3
    li   a3, 5
    jal  ra, .L_ks_knapsack
    addi s0, s0, -1
    j    .L_ks_outer

.L_ks_done:
    ld   s0, 0(sp)
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

.L_ks_knapsack:
    addi sp, sp, -80
    sd   ra, 72(sp)
    sd   s0, 64(sp)
    sd   s1, 56(sp)
    sd   s2, 48(sp)
    sd   s3, 40(sp)
    sd   s4, 32(sp)
    sd   s5, 24(sp)
    sd   s6, 16(sp)
    sd   s7, 8(sp)

    mv   s0, a0            # weights
    mv   s1, a1            # values
    mv   s2, a2            # n
    mv   s3, a3            # capacity

    # Allocate dp[(capacity+1)] on stack
    addi a0, s3, 1
    slli a0, a0, 2
    mv   s5, a0
    sub  sp, sp, a0
    mv   s4, sp

    # Clear dp
    mv   t0, zero
    addi t1, s3, 1
.L_ks_clear:
    beq  t0, t1, .L_ks_clear_done
    slli t2, t0, 2
    add  t2, s4, t2
    sw   zero, 0(t2)
    addi t0, t0, 1
    j    .L_ks_clear
.L_ks_clear_done:

    mv   t0, zero          # i = 0
.L_ks_i:
    bge  t0, s2, .L_ks_i_done
    slli t5, t0, 2
    add  t6, s0, t5
    lw   s6, 0(t6)         # weights[i]
    add  t6, s1, t5
    lw   s7, 0(t6)         # values[i]

    mv   t1, s3            # w = capacity
.L_ks_w:
    blt  t1, s6, .L_ks_w_done
    slli t5, t1, 2
    add  t5, s4, t5
    lw   t6, 0(t5)         # dp[w]
    sub  t2, t1, s6
    slli t2, t2, 2
    add  t2, s4, t2
    lw   t3, 0(t2)         # dp[w-weights[i]]
    add  t3, t3, s7
    bge  t6, t3, .L_ks_skip
    mv   t6, t3
    sw   t6, 0(t5)
.L_ks_skip:
    addi t1, t1, -1
    j    .L_ks_w
.L_ks_w_done:
    addi t0, t0, 1
    j    .L_ks_i
.L_ks_i_done:

    slli t5, s3, 2
    add  t5, s4, t5
    lw   a0, 0(t5)

    add  sp, sp, s5
    ld   s7, 8(sp)
    ld   s6, 16(sp)
    ld   s5, 24(sp)
    ld   s4, 32(sp)
    ld   s3, 40(sp)
    ld   s2, 48(sp)
    ld   s1, 56(sp)
    ld   s0, 64(sp)
    ld   ra, 72(sp)
    addi sp, sp, 80
    ret

.section .data
.align 4
.L_ks_weights:
    .word 2, 3, 4
.L_ks_values:
    .word 3, 4, 5
