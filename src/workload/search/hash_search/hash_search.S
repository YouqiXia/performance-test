    .text
    .global test_hash_search
    .balign 4
test_hash_search:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0            # nloop
    li   s1, 0             # result accumulator

    la   a0, .L_hs_table
    li   a1, 97            # table size
    li   t6, 12            # entry size

.L_hs_outer:
    beqz s0, .L_hs_done

    # Generate pseudo-random key from loop counter
    mv   a4, s0
    li   t0, 1103515245
    mul  a4, a4, t0
    li   t1, 12345
    add  a4, a4, t1
    srai t0, a4, 16
    andi a4, t0, 0x7FF

    # Hash: h(key) = (key * 13) % 97
    li   t0, 13
    mul  t1, a4, t0
    rem  t2, t1, a1        # hash index

    mul  t3, t2, t6
    add  t3, a0, t3        # entry address

.L_hs_probe:
    lw   t4, 8(t3)         # valid flag
    beqz t4, .L_hs_not_found
    lw   t5, 0(t3)         # key
    beq  t5, a4, .L_hs_found

    # Linear probing
    addi t2, t2, 1
    rem  t2, t2, a1
    mul  t3, t2, t6
    add  t3, a0, t3
    j    .L_hs_probe

.L_hs_found:
    lw   a5, 4(t3)
    j    .L_hs_add
.L_hs_not_found:
    li   a5, 0
.L_hs_add:
    add  s1, s1, a5
    addi s0, s0, -1
    j    .L_hs_outer

.L_hs_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret

.section .data
.align 4
.L_hs_table:
    .space 1164             # 97 * 12 bytes
    .word 42, 999, 1        # valid entry
    .word 123, 456, 1       # valid entry
