# FDIV↔FADD Forwarding Chain

测量 FDIV(fdiv.d) 和 FADD(fadd.d) 之间的双向 forwarding 延迟。

## 文档事实

- FDIV_lat 和 FADD_lat 可从 `latency/FDIV/fdiv_d` 和 `latency/FADD/fadd_d` 获取

## 待验证

- FDIV→FADD + FADD→FDIV 的 forwarding overhead 是否为零（即无额外旁路延迟）

## Critical Section

```asm
# 构造：fdiv.d/fadd.d 交替链，ft0 为链寄存器
# ft1=1.0 (fdiv identity: ft0/1.0=ft0), ft2=0.0 (fadd identity: ft0+0.0=ft0)
# .rept=20 因为 FDIV 延迟很高
# insn_per_iter=2
fdiv.d  ft0, ft0, ft1
fadd.d  ft0, ft0, ft2
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FDIV↔FADD | fdiv_fadd | ✅ | 20 | 2 | fdiv.d→fadd.d→fdiv.d 回环 |

## 解读

- `cycles/iter` = FDIV→FADD fwd + FADD_lat + FADD→FDIV fwd + FDIV_lat
- forwarding_overhead = `cycles/iter` - FDIV_lat - FADD_lat
- 若 overhead ≈ 0：FDIV 结果可直接 forward 到 FADD 输入，无额外延迟
- 若 overhead > 0：存在跨 FDIV/FADD dispatch type 的旁路惩罚
