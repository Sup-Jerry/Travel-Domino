---
name: large-file-split-migration
description: 将数千行大文件按“保守迁移”方式拆分为 3-8 个职责模块，强调职责先分、分批迁移、等价性验证与可回滚提交。Use when users ask to split/refactor huge files, prevent regressions during extraction, or need migration checklists/facade strategy for safe decomposition.
---

# Large File Split Migration

## 目标
将“大文件拆分”从一次性重构，变为低风险迁移流程：
- 先做职责划分，再做文件拆分
- 每轮只迁移一个职责块
- 迁移阶段不改业务行为
- 每轮做等价性验证并可独立提交

## 执行顺序（严格）
1. 冻结边界：写明本轮只迁移什么，不迁移什么。
2. 绘制职责地图：把原文件分为 3-8 个职责块。
3. 生成迁移卡：为本轮模块列出方法、常量、类型、副作用、调用点。
4. 先建壳后搬家：先创建新模块入口，再逐段迁移实现。
5. 只迁移一块：迁移后立即验证，不并行做“重命名/算法优化/目录大改”。
6. 等价性验证：输入输出、关键路径、边界场景、副作用一致。
7. 清理旧逻辑：仅在验证通过后删除旧代码，再回归一次。
8. 小步提交：每完成一个职责块就提交一次，保证可回滚。

## 迁移卡模板（必须）
每个待迁移模块都创建一张卡，使用 [migration-template.md](references/migration-template.md)。

## 等价性验证（必须）
使用 [equivalence-matrix.md](references/equivalence-matrix.md) 记录结果。

## 可复用脚本
- `scripts/checklist.ps1`：快速生成迁移卡骨架。
