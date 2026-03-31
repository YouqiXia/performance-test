# LD↔ALU (L1) Forwarding Chain

测量 L1 load 与 ALU(add) 之间的往返 forwarding 延迟。

## 文档事实

- LD_lat(L1) 可从 `latency/LOAD/ld` 获取
- ALU_lat 可从 `latency/ALU/add` 获取

## 待验证

- LD→ALU + ALU→LD 的 forwarding overhead 是否为零

## Critical Section

```asm
# 构造：ld/add 交替链，t0 为链寄存器（自环指针）
# add zero = identity，不改变 t0 值
# insn_per_iter=2
ld   t0, 0(t0)
add  t0, t0, zero
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| LD↔ALU | ld_alu | ✅ | 100 | 2 | ld→add→ld 回环 |

## 解读

- `cycles/iter` = LD→ALU fwd + ALU_lat + ALU→LD fwd + LD_lat(L1)
- forwarding_overhead = `cycles/iter` - LD_lat(L1) - ALU_lat
- 若 overhead ≈ 0：load-to-ALU forwarding 无额外延迟
- 若 overhead > 0：存在 load-use penalty 或跨 dispatch type 旁路惩罚
