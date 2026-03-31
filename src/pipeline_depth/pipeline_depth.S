    .text

# =============================================================================
# Speculative Wakeup Replay Penalty Test
#
# 利用 L1 set conflict 制造 "surprise" L1 miss，观测 replay penalty。
#
# K3 DCache = 64KB, 4-way, 64B cacheline → 256 sets
# 同 set 不同 way 的地址间隔 = 64KB / 4 = 16KB
#
# 三个测试对比：
#   Test A: 4 个同 set 地址循环访问（全 L1 hit，无 replay）
#   Test B: 5 个同 set 地址 + 回访被 evict 的（surprise L1 miss → replay）
#   Test C: 固定 5+1 模式（scheduler 可学习 miss 模式 → 适应后无 replay）
#
# replay penalty = (Test B 的 miss 处 cycles) - (Test C 的 miss 处 cycles)
# 若 Test B ≈ Test C → scheduler 不做 speculative wakeup 或总是保守
# 若 Test B > Test C → surprise miss 导致了额外的 replay 惩罚
#
# Signature: void test_xxx(uint64_t nloop, uint64_t **addrs)
#   a0 = nloop, a1 = addrs[5]（5 个同 set 地址的指针数组）
# =============================================================================

    .global test_replay_l1_hit
    .global test_replay_surprise_miss
    .global test_replay_always_miss

# ---------- Test A: 全部 L1 hit（baseline，无 replay）----------
# 构造：只访问前 4 个同 set 地址，4-way 全部 hit。
# scheduler 训练为 L1 时序唤醒，consumer 总是成功。
test_replay_l1_hit:
    mv   t3, a0
    ld   a2, 0(a1)         # addr[0]
    ld   a3, 8(a1)         # addr[1]
    ld   a4, 16(a1)        # addr[2]
    ld   a5, 24(a1)        # addr[3]
.Lhit_loop:
    beqz t3, .Lhit_done
    .rept 25
    ld   t0, 0(a2)
    add  t0, t0, zero      # consumer: L1 hit, wakeup 成功

    ld   t0, 0(a3)
    add  t0, t0, zero

    ld   t0, 0(a4)
    add  t0, t0, zero

    ld   t0, 0(a5)
    add  t0, t0, zero
    .endr
    addi t3, t3, -1
    j    .Lhit_loop
.Lhit_done:
    ret

# ---------- Test B: Surprise miss（有 replay）----------
# 构造：先访问 4 个（L1 hit，训练 scheduler）→ 访问第 5 个（evict addr[0]）
# → 再访问 addr[0]（surprise L1 miss！scheduler 按 L1 时序唤醒 → 数据没到 → replay）
test_replay_surprise_miss:
    mv   t3, a0
    ld   a2, 0(a1)         # addr[0]
    ld   a3, 8(a1)         # addr[1]
    ld   a4, 16(a1)        # addr[2]
    ld   a5, 24(a1)        # addr[3]
    ld   a6, 32(a1)        # addr[4] — 第 5 路，evict addr[0]
.Lmiss_loop:
    beqz t3, .Lmiss_done
    .rept 25
    # 前 4 个 L1 hit（训练 scheduler）
    ld   t0, 0(a2)
    add  t0, t0, zero

    ld   t0, 0(a3)
    add  t0, t0, zero

    ld   t0, 0(a4)
    add  t0, t0, zero

    ld   t0, 0(a5)
    add  t0, t0, zero

    # 第 5 个：evict addr[0]
    ld   t0, 0(a6)
    add  t0, t0, zero

    # 回访 addr[0]：刚被 evict → surprise L1 miss!
    ld   t0, 0(a2)
    add  t0, t0, zero      # consumer: 可能被按 L1 时序唤醒 → replay
    .endr
    addi t3, t3, -1
    j    .Lmiss_loop
.Lmiss_done:
    ret

# ---------- Test C: Always 5+1 模式（scheduler 可学习）----------
# 构造：和 Test B 完全相同的访问序列，但每次都跑。
# 如果 scheduler 有 miss predictor，经过多次后它会学会第 6 个 ld 是 miss，
# 按 L2 时序唤醒 → 无 replay。
# 若 Test C ≈ Test B → scheduler 没有 miss predictor（或不做投机唤醒）
# 若 Test C < Test B → scheduler 学会了 miss 模式，减少了 replay
test_replay_always_miss:
    mv   t3, a0
    ld   a2, 0(a1)
    ld   a3, 8(a1)
    ld   a4, 16(a1)
    ld   a5, 24(a1)
    ld   a6, 32(a1)
.Lalways_loop:
    beqz t3, .Lalways_done
    .rept 25
    ld   t0, 0(a2)
    add  t0, t0, zero

    ld   t0, 0(a3)
    add  t0, t0, zero

    ld   t0, 0(a4)
    add  t0, t0, zero

    ld   t0, 0(a5)
    add  t0, t0, zero

    ld   t0, 0(a6)
    add  t0, t0, zero

    ld   t0, 0(a2)
    add  t0, t0, zero
    .endr
    addi t3, t3, -1
    j    .Lalways_loop
.Lalways_done:
    ret
