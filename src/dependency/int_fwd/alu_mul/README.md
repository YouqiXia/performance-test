# ALU↔MUL Forwarding Chain

测量 ALU(add) 和 MUL(mul) 之间的双向 forwarding 延迟。

## 文档事实

- ALU_lat 和 MUL_lat 可从 `latency/ALU/add` 和 `latency/MUL/mul` 获取

## 待验证

- ALU→MUL + MUL→ALU 的 forwarding overhead 是否为零（即无额外旁路延迟）

## Critical Section

```asm
# 构造：add/mul 交替链，t0 为链寄存器
# t1=0 (add identity), t2=1 (mul identity)
# insn_per_iter=2
add  t0, t0, t1
mul  t0, t0, t2
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| ALU↔MUL | alu_mul | ✅ | 100 | 2 | add→mul→add 回环 |

## 解读

- `cycles/iter` = ALU→MUL fwd + MUL_lat + MUL→ALU fwd + ALU_lat
- forwarding_overhead = `cycles/iter` - ALU_lat - MUL_lat
- 若 overhead ≈ 0：forwarding 无额外延迟
- 若 overhead > 0：存在跨 dispatch type 的旁路惩罚
