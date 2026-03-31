# SD↔LD INT Store Forwarding

INT store forwarding latency. cycles/iter = store buffer → load bypass 往返。

## 文档事实

- SD latency 可从 `latency/STORE/sd` 获取
- LD latency (L1) 可从 `latency/LOAD/ld` 获取

## 待验证

- INT sd→ld store forwarding 的往返延迟
- store buffer bypass 是否引入额外惩罚

## Critical Section

```asm
# 构造：sd/ld 交替链，t0 为链寄存器，a1 为固定内存地址
# sd 写 t0 到 [a1]，ld 从 [a1] 读回 t0（store forwarding）
# insn_per_iter=2
sd   t0, 0(a1)
ld   t0, 0(a1)
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| SD↔LD | sd_ld | ✅ | 100 | 2 | sd→ld store forwarding 回环 |

## 解读

- `cycles/iter` = sd→ld store forwarding 往返延迟
- 该值是 fsd_fld 等 FP store forwarding 测试的 INT baseline
- 若 cycles/iter 显著高于 LD_lat(L1)：store buffer forwarding 存在额外延迟
