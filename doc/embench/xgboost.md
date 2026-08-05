# xgboost 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/xgboost/testbench.c` + `xgboost.c` + `xgboost.h`
- **算法描述**: XGBoost 决策树集成推理，对 128 个样本做 10 类分类（400 棵决策树）
- **LOCAL_SCALE_FACTOR**: 1
- **数据类型**: `uint8_t`（特征值、树节点值、叶值），`uint16_t`（投票累加）

### 1.2 调用链
```
benchmark() → benchmark_body(lsf=1, gsf=1)
  └→ 循环 1×1 = 1 次（+ warmup 1 次 = 2 总计）
      └→ for i = 0..127 (128 samples)
          └→ predict(X_test[i])
              ├→ for class = 0..9 (10 classes)
              │   └→ for tree = 0..39 (40 trees)
              │       └→ while(非叶节点) 遍历决策树 ★热点
              └→ argmax(votes[10]) 返回分类结果
```

### 1.3 核心计算函数

```c
uint8_t predict(const uint8_t *x) {
    uint16_t votes[NUM_CLASSES] = { 0 };  // 10 个类的投票

    size_t tree_idx = 0, node_base = 0, leaf_base = 0;
    for (size_t i = 0; i < NUM_CLASSES; i++) {      // 10 classes
        for (size_t j = 0; j < NUM_TREES; j++) {    // 40 trees
            const uint8_t tree_size = tree_sizes[tree_idx];
            // ... 获取当前树的各数组指针

            uint8_t node_id = 0;
            while(!(node_id & 0x80)) {               // ★热点: 树遍历
                const uint16_t node_idx = tree_idxs[node_id];
                const uint8_t node_value = tree_values[node_id];
                if (x[node_idx] < node_value)
                    node_id = tree_left_children[node_id];
                else
                    node_id = tree_right_children[node_id];
            }
            uint8_t leaf_idx = node_id & 0x7F;
            votes[i] += tree_leaf_values[leaf_idx];

            tree_idx++;
            node_base += tree_size;
            leaf_base += tree_size + 1;
        }
    }
    // argmax(votes)
    return class_idx;
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| benchmark_body 外层 | lsf_cnt | 1 | LOCAL_SCALE_FACTOR |
| benchmark_body 内层 | gsf_cnt | 1 | GLOBAL_SCALE_FACTOR |
| Sample 循环 | i | 128 | SAMPLES_IN_FILE |
| Class 循环 | i (predict) | 10 | NUM_CLASSES |
| Tree 循环 | j (predict) | 40 | NUM_TREES |
| **树遍历** | **while** | **~3.58 avg** | **数据依赖的不规则循环 ★热点** |
| Argmax | i | 9 | 遍历 votes[1..9] |

**总树遍历次数**: 128 × 10 × 40 × 2 = 102,400（含 warmup）
**总比较次数**: 366,564（平均每棵树 ~3.58 次比较）

### 1.5 访存模式

| 数组 | 大小 | 访问方式 | 说明 |
|------|------|---------|------|
| X_test[128][64] | 8,192B | 随机偏移 | 每次比较按 node_idx 索引特征 |
| tree_sizes[400] | 400B | 顺序 | 每棵树读一次 |
| comparison_idxs[6087] | 6,087B | 按 node_id 索引 | 决策节点的特征索引 |
| comparison_values[6087] | 6,087B | 按 node_id 索引 | 决策阈值 |
| left_children[6087] | 6,087B | 按 node_id 索引 | 左子节点 ID |
| right_children[6087] | 6,087B | 按 node_id 索引 | 右子节点 ID |
| leaf_values[6487] | 6,487B | 按 leaf_idx 索引 | 叶节点投票值 |
| votes[10] | 20B | 随机写 | 栈上累加器 |

**数据总量**: ~39KB → **大部分驻 L1D**（32KB L1D 可能有溢出到 L2 的情况）

### 1.6 计算特征

- **访存密集型 + 控制流密集型**: 每次比较需 5 次 `lbu`（node_idx, node_value, x[idx], left/right child）
- **运算类型**: `lbu`（无符号字节加载）+ `bltu`（比较分支）+ 少量 `add`/`andi`
- **分支**: 树遍历的 `if (x[idx] < value)` 是数据依赖分支，**不可预测**
- **指针追踪**: node_id 依赖上一次比较结果 → **串行依赖链**，OoO 核难以并行

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 3,506,160
Cycles:  3,506,156
Instret: 3,506,160
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

**predict 函数：树遍历热点循环**:
```asm
  # 寄存器分配:
  # a0 = x (输入样本指针), a1 = node_base (累加偏移)
  # a7 = comparison_idxs 基址, a6 = comparison_values 基址
  # t3 = right_children 基址, t1 = left_children 基址
  # s0 = leaf_values 基址, t5 = leaf_base (累加偏移)
  # a3 = node_value (比较阈值), a4 = x[node_idx] (特征值)

  # === 新树入口: 从 tree_sizes 读取大小，重置 node_id ===
  1050c:  lbu   t6, 0(t4)          # t6 = tree_sizes[tree_idx]
  10510:  mv    a5, a1             # a5 = node_base (当前树在数组中的偏移)
  ...
  # === 比较路径公共入口 ===
  10530:  lbu   a4, 0(s3)          # a4 = comparison_idxs[node_id] (特征索引)
  10534:  lbu   a3, 0(a2)          # a3 = comparison_values[node_id] (阈值)
  10538:  add   a4, a4, a0         # a4 = &x[node_idx]
  1053a:  lbu   a4, 0(a4)          # a4 = x[node_idx] (特征值)
  1053e:  add   a2, t3, a5         # a2 = &right_children[node_id]
  10542:  add   a5, a5, t1         # a5 = &left_children[node_id]
  10544:  bltu  a4, a3, 0x10514   # if x[idx] < value → 走左子树

  # === 右子树路径 ===
  10548:  lbu   a3, 0(a2)          # a3 = right_children[node_id]
  1054c:  slliw a4, a3, 0x18       # 检查 MSB (叶节点标记)
  10550:  add   a5, a1, a3         # a5 = node_base + new_node_id
  10554:  sraiw a4, a4, 0x18       # 符号扩展: 叶节点 → 负数
  10558:  add   s3, a7, a5         # s3 = &comparison_idxs[new_node_id]
  1055c:  add   a2, a6, a5         # a2 = &comparison_values[new_node_id]
  10560:  bgez  a4, 0x10530       # 非叶节点 → 继续遍历

  # === 左子树路径 (10514) ===
  10514:  lbu   a3, 0(a5)          # a3 = left_children[node_id]
  10518:  slliw a4, a3, 0x18       # 检查 MSB
  1051c:  add   a5, a1, a3         # a5 = node_base + new_node_id
  10520:  sraiw a4, a4, 0x18       # 符号扩展
  10524:  add   s3, a7, a5         # s3 = &comparison_idxs[new_node_id]
  10528:  add   a2, a6, a5         # a2 = &comparison_values[new_node_id]
  1052c:  bltz  a4, 0x10564       # 叶节点 → 跳到叶处理

  # === 找到叶节点 ===
  10564:  andi  a3, a3, 127        # a3 = node_id & 0x7F (清除 MSB)
  10568:  add   a3, a3, t5         # a3 += leaf_base
  1056a:  add   a3, a3, s0         # a3 = &leaf_values[leaf_idx]
  1056c:  lbu   a5, 0(a3)          # a5 = leaf_value
  10570:  lhu   a3, 0(t0)          # a3 = votes[class]
  10574:  addiw a4, t6, 1          # a4 = tree_size + 1
  10578:  addi  t4, t4, 1          # tree_idx++
  1057a:  addw  a5, a5, a3         # a5 = leaf_value + votes[class]
  1057c:  sh    a5, 0(t0)          # votes[class] = a5
  10580:  add   a1, a1, t6         # node_base += tree_size
  10582:  add   t5, t5, a4         # leaf_base += tree_size + 1
  10584:  beq   t2, t4, 0x1059a   # 40 棵树完成 → 下一个 class
```

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| **比较+右分支** | `0x10530 - 0x10544` | **264,164~366,564** | 5 | **~1,648,020** | **23.4%** |
| **右子树路径** | `0x10548 - 0x10560` | **160,208** | 7 | **1,121,456** | **16.0%** |
| **左子树路径** | `0x10514 - 0x1052c` | **206,356** | 7 | **1,444,492** | **20.6%** |
| **叶节点处理** | `0x10564 - 0x10584` | **102,400** | 13 | **1,331,200** | **18.9%** |
| 新树入口 | `0x1050c - 0x10512` | 102,400 | 3 | 307,200 | 4.4% |
| 树/class 循环控制 | `0x10588 - 0x105b4` | ~99,840 | ~8 | ~798,720 | 11.4% |
| argmax + 其余 | — | — | — | ~377,872 | 5.4% |
| **合计** | — | — | — | **~7,028,960** | **100%** |

**执行次数验证**:
- 叶节点到达: 102,400 = 128 × 10 × 40 × 2 ✓（含 warmup）
- 左分支: 206,356 次，右分支: 160,208 次
- 总比较: 206,356 + 160,208 = 366,564 = 102,400 × 3.58 ✓
- 左/右比例: 56.3% / 43.7%（左分支略多）

### 2.4 内层循环微架构分析

**树遍历指令混合**（每次比较 ~12 条，含分支路径）:
- lbu: 4 (33.3%) — 加载 node_idx、value、feature、child_id
- add: 3 (25.0%) — 地址计算
- slliw/sraiw: 2 (16.7%) — 叶节点检测
- bltu/bgez/bltz: 1 (8.3%) — 数据依赖分支
- 其余: 2 (16.7%)

**关键依赖链**（单次树比较）:
```
lbu a3 (comparison_idxs) ─→ add a4,a4,a0 ─→ lbu a4 (x[idx]) ─→ bltu a4,a3
                                                                      │
                    ┌─────────────────────────────────────────────────┘
                    ↓
              lbu a3 (left/right child) ─→ slliw/sraiw ─→ bgez/bltz (叶检测)
                    │
                    ↓ (如果非叶)
              add s3/a2 (新地址) ─→ lbu (下一轮 idx/value)
```
延迟: lbu(2) + add(1) + lbu(2) + bltu(1) + lbu(2) + slliw(1) + sraiw(1) + bgez(1) = **~10 cycles/比较**

**循环携带依赖**:
- `node_id` (a3/a5): 每次比较的 node_id 依赖上次比较的 left/right child → **串行指针追踪**
- 无法跨比较并行：下一次比较的地址完全依赖本次比较的分支结果

**分支预测挑战**:
- `bltu a4,a3`：x[node_idx] vs threshold，**数据依赖，难以预测**
- 左/右分支比约 56:44，非极端偏斜
- 不同样本走不同树路径 → BTB/pattern history 效果有限

**预计 IPC (OoO core)**:
- 树遍历: ~12 条 / ~10 cycles ≈ 1.2（理想情况）
- 但分支误预测会导致 pipeline flush（~10-15 cycles penalty）
- 若 50% 误预测率，有效 IPC 可能降至 0.5~0.8
- 叶节点处理 13 条指令间依赖较少，可并行

## 3. 总结

```
算法:           XGBoost 决策树集成推理 (128 samples × 400 trees)
数据量:         ~39KB (树结构 ~31KB + 测试样本 8KB, L1D 可能部分溢出)
计算类型:       lbu 密集 + 数据依赖分支
内层循环指令数: ~12 条/比较 (含分支路径)
树遍历占比:     ~60% (比较 + 左/右路径)
瓶颈预测:       branch-misprediction-bound (数据依赖分支 + 指针追踪串行链)
分支特征:       树遍历分支完全数据依赖, 难以预测; 左/右比 56:44
特殊:           pointer-chase 模式 (node_id → child → next node_id), OoO 核难并行
```
