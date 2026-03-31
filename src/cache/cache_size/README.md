# Cache Size

通过 pointer chase latency 跳变检测 cache 层级边界和大小。

## 文档事实
- 64KB 4-Way L1 DCache, L2 Cache

## 待验证
- 各级 cache 的实际大小（latency 跳变点）

## Critical Section

本测试用纯 C 实现（main.c），无 .S 文件。核心循环为 pointer chase，有 4 种策略：

### Basic: 基础 pointer chase（对照组）
```c
// 构造：随机链表遍历，每个节点占 1 个 cacheline（64B）。insn_per_iter=1
// 最简单的 pointer chase，对抗 prefetcher 能力最弱。
p = (void **)*p;
```

### XOR: 加密指针
```c
// 构造：内存中存的是 (real_addr XOR key)，读出后必须 XOR 解密。insn_per_iter=2
// → 对抗 runahead / 预测执行型 prefetch（偷看内存也拿到密文）。
p = *(uintptr_t *)p;
p ^= XOR_KEY;
```

### Multi: 多链交织
```c
// 构造：4 条独立随机链表，每步用上次 load 结果低 2 bit 选链。insn_per_iter=3
// → 对抗 temporal stream prefetcher（多条流混在一起，无法建模）。
int c = selector & (NUM_CHAINS - 1);
p[c] = (void **)*p[c];
selector = (uintptr_t)p[c];
```

### XOR+Multi: 最强组合
```c
// 构造：同时使用加密指针和多链交织，最保守的 latency upper bound。insn_per_iter=4
int c = selector & (NUM_CHAINS - 1);
p[c] = *(uintptr_t *)p[c];
p[c] ^= XOR_KEY;
selector = p[c];
```

## 测试列表

| Test | 路径 | 链式? | .rept | insn_per_iter | 说明 |
|------|------|:---:|:---:|:---:|------|
| Basic | 随机 pointer chase | ✅ | N/A | 1 | 基础策略，随机链表遍历 |
| XOR | XOR 加密指针 | ✅ | N/A | 2 | 对抗 runahead / 预测执行型 prefetch |
| Multi | 多链交织 | ✅ | N/A | 3 | 4 条独立链数据依赖切换，对抗 stream prefetcher |
| XOR+Multi | XOR + 多链 | ✅ | N/A | 4 | 最强组合，最保守的 latency upper bound |

## 解读
- 不同工作集大小（4KB → 32MB）下的 ns/access
- latency 跳变点 = cache 层级边界（L1→L2→LLC→Memory）
- 若 Basic 和加强版 latency 差不多 → prefetcher 没有学到 pointer chase 模式
- 若加强版 latency 明显更高（尤其在 L2 区间）→ prefetcher 确实在帮忙，加强版数据更真实
- XOR 列反映 runahead prefetch 影响，Multi 列反映 stream correlation prefetch 影响
