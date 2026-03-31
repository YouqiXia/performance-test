# FCVT INT<->FP Roundtrip

测量 fcvt.d.w (INT->FP) 和 fcvt.w.d (FP->INT) 之间的跨域转换往返延迟。

## 文档事实

- fcvt.d.w 将整数寄存器转换为双精度浮点
- fcvt.w.d 将双精度浮点转换回整数寄存器
- 两条指令跨越 INT/FP 寄存器域，涉及跨域数据传递

## 待验证

- INT->FP convert + FP->INT convert 的往返延迟
- 跨域 forwarding 是否存在额外开销

## Critical Section

```asm
# 构造：fcvt.d.w/fcvt.w.d 交替链，t0 为 INT 链寄存器，ft0 为 FP 中间寄存器
# t0 初始化为 42，确保转换值在正常范围内
# insn_per_iter=2
fcvt.d.w  ft0, t0
fcvt.w.d  t0, ft0
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FCVT INT<->FP | fcvt_roundtrip | ✅ | 100 | 2 | fcvt.d.w->fcvt.w.d 回环 |

## 解读

- cycles/iter = INT->FP convert latency + FP->INT convert latency
- 与单独的 fcvt.d.w 和 fcvt.w.d latency 测试对比，差值反映跨域 forwarding overhead
