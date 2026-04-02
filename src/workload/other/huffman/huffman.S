    .text
    .global test_huffman
    .balign 4
test_huffman:
    addi sp, sp, -400
    sd   s0, 384(sp)
    sd   s1, 392(sp)
    mv   s0, a0            # nloop
    mv   s1, sp            # s1 = node base

    # Init 6 leaf nodes (32 bytes each: data,freq,left,right)
    # Node0: freq=5
    li   t0, 0
    sd   t0, 0(s1)
    li   t0, 5
    sd   t0, 8(s1)
    sd   zero, 16(s1)
    sd   zero, 24(s1)
    # Node1: freq=9
    li   t0, 1
    sd   t0, 32(s1)
    li   t0, 9
    sd   t0, 40(s1)
    sd   zero, 48(s1)
    sd   zero, 56(s1)
    # Node2: freq=12
    li   t0, 2
    sd   t0, 64(s1)
    li   t0, 12
    sd   t0, 72(s1)
    sd   zero, 80(s1)
    sd   zero, 88(s1)
    # Node3: freq=13
    li   t0, 3
    sd   t0, 96(s1)
    li   t0, 13
    sd   t0, 104(s1)
    sd   zero, 112(s1)
    sd   zero, 120(s1)
    # Node4: freq=16
    li   t0, 4
    sd   t0, 128(s1)
    li   t0, 16
    sd   t0, 136(s1)
    sd   zero, 144(s1)
    sd   zero, 152(s1)
    # Node5: freq=45
    li   t0, 5
    sd   t0, 160(s1)
    li   t0, 45
    sd   t0, 168(s1)
    sd   zero, 176(s1)
    sd   zero, 184(s1)

.L_hf_outer:
    beqz s0, .L_hf_done

    # Merge1: N0(5)+N1(9) -> N6 at offset 192
    li   t0, -1
    sd   t0, 192(s1)
    ld   t1, 8(s1)
    ld   t2, 40(s1)
    add  t3, t1, t2
    sd   t3, 200(s1)
    mv   t4, s1
    sd   t4, 208(s1)
    addi t4, s1, 32
    sd   t4, 216(s1)

    # Merge2: N2(12)+N3(13) -> N7 at offset 224
    li   t0, -1
    sd   t0, 224(s1)
    ld   t1, 72(s1)
    ld   t2, 104(s1)
    add  t3, t1, t2
    sd   t3, 232(s1)
    addi t4, s1, 64
    sd   t4, 240(s1)
    addi t4, s1, 96
    sd   t4, 248(s1)

    # Merge3: N6(14)+N4(16) -> N8 at offset 256
    li   t0, -1
    sd   t0, 256(s1)
    ld   t1, 200(s1)
    ld   t2, 136(s1)
    add  t3, t1, t2
    sd   t3, 264(s1)
    addi t4, s1, 192
    sd   t4, 272(s1)
    addi t4, s1, 128
    sd   t4, 280(s1)

    # Merge4: N7(25)+N8(30) -> N9 at offset 288
    li   t0, -1
    sd   t0, 288(s1)
    ld   t1, 232(s1)
    ld   t2, 264(s1)
    add  t3, t1, t2
    sd   t3, 296(s1)
    addi t4, s1, 224
    sd   t4, 304(s1)
    addi t4, s1, 256
    sd   t4, 312(s1)

    # Merge5: N5(45)+N9(55) -> Root at offset 320
    li   t0, -1
    sd   t0, 320(s1)
    ld   t1, 168(s1)
    ld   t2, 296(s1)
    add  t3, t1, t2
    sd   t3, 328(s1)
    addi t4, s1, 160
    sd   t4, 336(s1)
    addi t4, s1, 288
    sd   t4, 344(s1)

    addi s0, s0, -1
    j    .L_hf_outer

.L_hf_done:
    ld   a0, 328(s1)       # root freq = 100
    ld   s0, 384(sp)
    ld   s1, 392(sp)
    addi sp, sp, 400
    ret
