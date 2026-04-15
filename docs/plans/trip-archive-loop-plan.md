# 计划—执行—归档闭环实施计划

## 1. 痛点定义

**当前状态**：行程用完即走，没有到访记录、花费、照片挂载，无法复盘，历史路线无法复用为模板。

**目标状态**：每次旅行结束后，系统自动生成归档记录；历史行程可一键复用为新计划模板；用户越用越依赖沉淀下来的旅行资产。

---

## 2. 成功标准

- 事件可标记"已到访 / 已跳过（含原因）"
- 花费、备注、照片可挂载到单个事件
- 行程结束后可一键生成复盘摘要
- 历史行程可复用为模板（去除时间，保留结构）
- 全链路日志前缀：`ARCHIVE_TRACE`

---

## 3. 范围

**包含**：
- 事件到访状态记录（到访 / 跳过 + 原因）
- 花费 / 备注挂载到事件
- 照片 URI 挂载到事件（本地路径，不上传）
- 行程复盘摘要生成
- 历史行程转模板

**不包含**：
- 云端照片同步
- 社交分享
- 多人协作归档

---

## 4. 目标文件与职责

### 4.1 新增文件

| 文件 | 职责 |
|------|------|
| `domain/archive/services/ArchiveService.ets` | 复盘生成、模板转换 |
| `domain/archive/models/ArchiveModels.ets` | 数据结构定义 |
| `infrastructure/persistence/ArchiveRepositoryImpl.ets` | 归档数据持久化 |

### 4.2 修改文件

| 文件 | 改动 |
|------|------|
| `model/entity/EventEntity.ets` | 新增 visitStatus / skipReason / expense / note / photoUri 字段 |
| `infrastructure/persistence/EventRepositoryImpl.ets` | 支持更新上述字段 |
| `viewmodel/TimelineViewModel.ets` | 暴露归档操作方法 |

---

## 5. 数据结构

```typescript
// ArchiveModels.ets

export type VisitStatus = 'PENDING' | 'VISITED' | 'SKIPPED';

export interface EventArchiveData {
  eventId: number;
  visitStatus: VisitStatus;
  skipReason?: string;
  expense?: number;        // 单位：分
  note?: string;
  photoUri?: string;       // 本地图片路径
}

export interface TripArchive {
  planId: number;
  title: string;
  startDate: string;
  endDate: string;
  totalExpense: number;
  visitedCount: number;
  skippedCount: number;
  summary: string;         // AI 生成或规则生成的复盘文字
  events: EventArchiveData[];
  createdAt: number;
}

export interface TripTemplate {
  sourceArchiveId: number;
  name: string;
  events: TemplateEventItem[];  // 去除时间，保留结构
}

export interface TemplateEventItem {
  name: string;
  duration: number;
  itemType: number;
  note?: string;
}
```

---

## 6. 分阶段实施

### Phase A：事件归档字段

**目标**：事件可记录到访状态、花费、备注、照片。

**实现**：
- `EventEntity` 新增字段（数据库迁移脚本同步更新）
- `EventRepositoryImpl.updateArchiveData(eventId, data)` 写入
- ViewModel 暴露 `markVisited(eventId)` / `markSkipped(eventId, reason)` / `updateExpense(eventId, amount)` / `attachNote(eventId, note)` / `attachPhoto(eventId, uri)`

**交付物**：
- 字段可读写，单测通过

---

### Phase B：复盘摘要生成

**目标**：行程结束后一键生成复盘。

**实现**：`ArchiveService.generateSummary(planId)` → `TripArchive`

摘要内容（规则生成，不强依赖 AI）：
- 总天数、总事件数、到访率
- 花费合计
- 跳过事件及原因列表
- 可选：调用 AI 生成一段自然语言总结（失败时用规则文本兜底）

**交付物**：
- 规则摘要可独立生成，不依赖 AI
- AI 失败有兜底文本

---

### Phase C：历史行程转模板

**目标**：历史归档可一键转为可复用模板。

**实现**：`ArchiveService.toTemplate(archive)` → `TripTemplate`

- 去除所有时间信息（startTime / dayOffset 清零）
- 保留：name / duration / itemType / note
- 模板可在新建行程时选择导入

**ViewModel 新增**：
```typescript
savedTemplates: TripTemplate[]
saveAsTemplate(planId: number): Promise<void>
applyTemplate(template: TripTemplate): Promise<void>
```

**交付物**：
- 模板保存与导入可走通

---

### Phase D：页面集成

**目标**：在时间轴页面支持归档操作，新建行程支持选模板。

**时间轴页面**：
- 每个事件长按菜单新增：标记到访 / 标记跳过 / 记录花费 / 添加备注 / 挂载照片
- 行程结束后顶部出现"生成复盘"入口

**新建行程页面**：
- 新增"从模板创建"选项，展示历史模板列表

---

### Phase E：测试与门禁

**测试文件**：
- `entry/src/test/ArchiveService.test.ets`
- `entry/src/test/ArchiveRepository.test.ets`

**门禁**：
- `./scripts/ci/unit-all.ps1` 全量通过

---

## 7. 稳定性约束

- 归档操作不影响正在执行的行程状态
- 照片仅存本地 URI，不上传，不校验文件存在性
- AI 摘要失败必须有规则兜底，不阻断归档流程
- 数据库字段新增需提供迁移脚本，旧数据默认值安全

---

## 8. 执行顺序

1. Phase A — 事件归档字段
2. Phase B — 复盘摘要生成
3. Phase C — 历史行程转模板
4. Phase D — 页面集成
5. Phase E — 测试门禁

---

## 9. 完成定义（DoD）

- [ ] 事件可标记到访 / 跳过（含原因）
- [ ] 花费、备注、照片可挂载到事件
- [ ] 行程结束可生成复盘摘要（规则兜底）
- [ ] 历史行程可转为模板并在新建时复用
- [ ] AI 摘要失败不阻断归档
- [ ] 数据库迁移脚本安全（旧数据有默认值）
- [ ] 单测覆盖归档生成与模板转换
