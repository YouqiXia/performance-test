# FDIV↔FMUL Forwarding Chain

测量 FDIV(fdiv.d) 和 FMUL(fmul.d) 之间的双向 forwarding 延迟。

## 文档事实

- FDIV_lat 和 FMUL_lat 可从 `latency/FDIV/fdiv_d` 和 `latency/FMUL/fmul_d` 获取

## 待验证

- FDIV→FMUL + FMUL→FDIV 的 forwarding overhead 是否为零（即无额外旁路延迟）

## Critical Section

```asm
# 构造：fdiv.d/fmul.d 交替链，ft0 为链寄存器
# ft1=1.0 (div identity), ft2=1.0 (mul identity)
# insn_per_iter=2
fdiv.d  ft0, ft0, ft1
fmul.d  ft0, ft0, ft2
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FDIV↔FMUL | fdiv_fmul | ✅ | 20 | 2 | fdiv.d→fmul.d→fdiv.d 回环 |

## 解读

- `cycles/iter` = FDIV→FMUL fwd + FMUL_lat + FMUL→FDIV fwd + FDIV_lat
- forwarding_overhead = `cycles/iter` - FDIV_lat - FMUL_lat
- 若 overhead ≈ 0：forwarding 无额外延迟
- 若 overhead > 0：存在跨 FP dispatch type 的旁路惩罚
