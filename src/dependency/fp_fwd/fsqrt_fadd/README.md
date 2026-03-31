# FSQRT↔FADD Forwarding Chain

测量 FSQRT(fsqrt.d) 和 FADD(fadd.d) 之间的双向 forwarding 延迟。

## 文档事实

- FSQRT_lat 和 FADD_lat 可从 `latency/FSQRT/fsqrt_d` 和 `latency/FADD/fadd_d` 获取

## 待验证

- FSQRT→FADD + FADD→FSQRT 的 forwarding overhead 是否为零（即无额外旁路延迟）

## Critical Section

```asm
# 构造：fsqrt.d/fadd.d 交替链，ft0 为链寄存器
# ft0 init 1.0 (sqrt(1)=1, stable), ft1=0.0 (fadd identity)
# insn_per_iter=2
fsqrt.d ft0, ft0
fadd.d  ft0, ft0, ft1
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FSQRT↔FADD | fsqrt_fadd | ✅ | 20 | 2 | fsqrt.d→fadd.d→fsqrt.d 回环 |

## 解读

- `cycles/iter` = FSQRT→FADD fwd + FADD_lat + FADD→FSQRT fwd + FSQRT_lat
- forwarding_overhead = `cycles/iter` - FSQRT_lat - FADD_lat
- 若 overhead ≈ 0：forwarding 无额外延迟
- 若 overhead > 0：存在跨 FP dispatch type 的旁路惩罚
