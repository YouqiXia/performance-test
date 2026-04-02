    .text
    .global test_queue
    .balign 4
test_queue:
    addi sp, sp, -24
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    sd   s2, 16(sp)
    mv   s0, a0            # s0 = nloop
    li   s1, 0             # result accumulator
    li   s2, 1             # enqueue value

    la   a0, .L_q_data
    sw   zero, 64(a0)      # front = 0
    sw   zero, 68(a0)      # rear = 0

.L_q_outer:
    beqz s0, .L_q_done

    # Enqueue
    lw   t0, 68(a0)        # rear
    slli t1, t0, 2
    add  t2, a0, t1
    sw   s2, 0(t2)         # data[rear] = value
    addi t0, t0, 1
    li   t1, 16
    rem  t0, t0, t1        # rear = (rear+1) % 16
    sw   t0, 68(a0)
    addi s2, s2, 1

    # Dequeue
    lw   t0, 64(a0)        # front
    slli t1, t0, 2
    add  t2, a0, t1
    lw   t3, 0(t2)         # value = data[front]
    addi t0, t0, 1
    li   t1, 16
    rem  t0, t0, t1        # front = (front+1) % 16
    sw   t0, 64(a0)

    add  s1, s1, t3
    addi s0, s0, -1
    j    .L_q_outer

.L_q_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    ld   s2, 16(sp)
    addi sp, sp, 24
    ret

.section .data
.align 4
.L_q_data:
    .space 64               # data[16]
    .word 0                 # front (offset 64)
    .word 0                 # rear (offset 68)
