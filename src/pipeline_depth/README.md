# Pipeline Depth (Speculative Wakeup Replay)

利用 L1 set conflict 制造 "surprise" L1 miss，观测 speculative wakeup replay penalty。

## 文档事实
- speculative wakeup 机制；流水线 IS -> RF -> EX
- K3 DCache = 64KB, 4-way, 64B cacheline -> 256 sets
- 同 set 不同 way 的地址间隔 = 64KB / 4 = 16KB

## 待验证
- speculative wakeup 失败时的 replay penalty
- scheduler 是否有 miss predictor（能否学习 miss 模式）

## Critical Section

### Test A: 全部 L1 hit（baseline，无 replay）
```asm
# 构造：只访问前 4 个同 set 地址，4-way 全部 hit。insn_per_iter=2
# 为什么 4 个：K3 DCache 是 4-way，4 个同 set 地址恰好填满所有 way。
# scheduler 训练为 L1 时序唤醒，consumer 总是成功。
ld   t0, 0(a2)
add  t0, t0, zero      # consumer: L1 hit, wakeup 成功

ld   t0, 0(a3)
add  t0, t0, zero

ld   t0, 0(a4)
add  t0, t0, zero

ld   t0, 0(a5)
add  t0, t0, zero
```

### Test B: Surprise miss（有 replay）
```asm
# 构造：先访问 4 个（L1 hit，训练 scheduler）-> 访问第 5 个（evict addr[0]）-> 再访问 addr[0]（surprise L1 miss！）。insn_per_iter=2
# 为什么第 5 个会 evict：4-way set 已满，第 5 个同 set 地址必须 evict 一个。
# 为什么是 surprise：前 4 个都 hit，scheduler 按 L1 时序投机唤醒 consumer，
# 但回访 addr[0] 时已被 evict -> 数据没到 -> replay。
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

# 回访 addr[0]：刚被 evict -> surprise L1 miss!
ld   t0, 0(a2)
add  t0, t0, zero      # consumer: 可能被按 L1 时序唤醒 -> replay
```

### Test C: Always 5+1 模式（scheduler 可学习）
```asm
# 构造：和 Test B 完全相同的访问序列，但每次都跑。insn_per_iter=2
# 为什么和 Test B 一样：如果 scheduler 有 miss predictor，
# 经过多次后它会学会第 6 个 ld 是 miss，按 L2 时序唤醒 -> 无 replay。
# 若 Test C ≈ Test B -> scheduler 没有 miss predictor
# 若 Test C < Test B -> scheduler 学会了 miss 模式
ld   t0, 0(a2)
add  t0, t0, zero
... (same as Test B)
ld   t0, 0(a6)
add  t0, t0, zero
ld   t0, 0(a2)
add  t0, t0, zero
```

每组 .rept 25 展开。

## 测试列表

| Test | 路径 | 链式? | .rept | insn_per_iter | 说明 |
|------|------|:---:|:---:|:---:|------|
| A | 全部 L1 hit | - | 25 | 2 | 4 个同 set 地址循环访问，4-way 全 hit，baseline |
| B | Surprise miss | - | 25 | 2 | 5 个同 set + 回访被 evict 的，surprise L1 miss -> replay |
| C | Always 5+1 | - | 25 | 2 | 和 Test B 相同序列，scheduler 可学习 miss 模式 |

## 解读
- replay penalty = (Test B 的 miss 处 cycles) - (Test C 的 miss 处 cycles)
- 若 Test B ≈ Test C -> scheduler 不做 speculative wakeup 或总是保守等待
- 若 Test B > Test C -> surprise miss 导致了额外的 replay 惩罚，scheduler 有 miss predictor
- 5 个同 set 地址利用了 K3 的 4-way associativity 制造精确的 eviction
