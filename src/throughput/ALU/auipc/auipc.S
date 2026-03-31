    .text

# --- AUIPC: rd=PC+(imm<<12) ---
# Dispatch: ALU → INT Pipe 1
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_auipc
    .balign 4
test_auipc:
    mv   t3, a0
.L_auipc_loop:
    beqz t3, .L_auipc_done
    .rept 25
    auipc  t0, 0
    auipc  t1, 0
    auipc  t2, 0
    auipc  t4, 0
    .endr
    addi t3, t3, -1
    j    .L_auipc_loop
.L_auipc_done:
    ret
