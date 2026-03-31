    .text

# --- JALR: rd=PC+4; PC=(rs1+off)&~1 ---
# Dispatch: BRU → INT Pipe 1
# Expected throughput=1, latency=1
# 2 independent insns × .rept 50 = 100 insns/loop

    .global test_jalr
    .balign 4
test_jalr:
    mv   t3, a0
.L_jalr_loop:
    beqz t3, .L_jalr_done
    .rept 50
    auipc a5, 0
    jalr  t0, 8(a5)
    .endr
    addi t3, t3, -1
    j    .L_jalr_loop
.L_jalr_done:
    ret
