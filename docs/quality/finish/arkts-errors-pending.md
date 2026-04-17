# ArkTS 编译错误待修复清单

更新时间：2026-04-16

---

## Phase2BatchAQ.test.ets

| 行:列 | 错误规则 | 说明 |
|-------|---------|------|
| 577:62 | arkts-no-any-unknown | 使用了 `unknown` 类型，改为 `Object` |
| 1671:55 | arkts-no-any-unknown | 使用了 `unknown` 类型，改为 `Object` |

**修复方法：** `xxx as unknown as T` → `xxx as Object as T`

---

## Phase2BatchAR.test.ets

### 单行错误

| 行:列 | 错误规则 | 说明 |
|-------|---------|------|
| 110:14 | arkts-no-untyped-obj-literals | `return {} as Object` → `return new Object()` |

### 重复模式错误（arkts-no-noninferrable-arr-literals + arkts-no-untyped-obj-literals）

以下行均为数组字面量含无类型对象的模式，如 `[{ plan_id: X }]`：

| 行 | 错误规则 |
|----|---------|
| 1101 | arr-literals + untyped-obj |
| 1165 | arr-literals + untyped-obj |
| 1231 | arr-literals + untyped-obj |
| 1309 | arr-literals + untyped-obj |
| 1337 | arr-literals + untyped-obj |
| 1365 | arr-literals + untyped-obj |
| 1373 | arr-literals + untyped-obj |
| 1402 | arr-literals + untyped-obj |
| 1434 | arr-literals + untyped-obj |
| 1463 | arr-literals + untyped-obj |
| 1495 | arr-literals + untyped-obj |
| 1524 | arr-literals + untyped-obj |
| 1557 | arr-literals + untyped-obj |
| 1607 | arr-literals + untyped-obj |
| 1631 | arr-literals |
| 1632 | untyped-obj |
| 1633 | untyped-obj |
| 1634 | untyped-obj |
| 1672 | arr-literals + untyped-obj |
| 1736 | arr-literals + untyped-obj |
| 1774 | arr-literals |

**修复方法：**

```typescript
// 修复前
store.queueQueryRows([{ plan_id: 901 }]);

// 修复后（需在文件顶部定义 interface，如已有则复用）
interface PlanIdRowAR { plan_id: number }
const row: PlanIdRowAR = { plan_id: 901 };
store.queueQueryRows([row] as PlanIdRowAR[]);
```

多字段对象同理，每个元素先声明带类型变量，数组加类型注解。

---

## 统计

| 文件 | 错误数 |
|------|--------|
| Phase2BatchAQ.test.ets | 2 |
| Phase2BatchAR.test.ets | 39 |
| **合计** | **41** |
