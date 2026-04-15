# 碎片导入结构化实施计划

## 1. 痛点定义

**当前状态**：产品入口是"做完攻略再排程"，用户在小红书、微博、截图、笔记里看到灵感时，无法直接进入系统，需要手动复制粘贴再逐条录入。

**目标状态**：用户从"看到想去的内容"那一刻就能进入系统——粘贴链接、截图、文字片段，自动识别地点/时间/标签，一键转成计划项。

---

## 2. 成功标准

- 支持 3 种导入源：文字片段、截图（OCR）、链接（网页标题+正文）
- 识别准确率：地点 ≥ 85%，时长建议合理（可编辑）
- 识别结果可逐条确认/编辑后再入库
- 不依赖 OTA / 供应链 / 支付
- 全链路日志前缀：`IMPORT_TRACE`

---

## 3. 范围

**包含**：
- 文字片段解析（粘贴板 / 手动输入）
- 截图 OCR 文字提取后解析
- 链接导入（抓取标题 + 正文关键段落后解析）
- 识别结果预览与逐条确认
- 一键转为计划项写入时间轴

**不包含**：
- 小红书 / 抖音 App 内分享协议对接（平台限制）
- 自动同步收藏夹
- 图片内容语义识别（非文字）

---

## 4. 目标文件与职责

### 4.1 新增文件

| 文件 | 职责 |
|------|------|
| `domain/import/services/FragmentParserService.ets` | 文字片段 → 结构化候选项 |
| `domain/import/services/LinkFetchService.ets` | 链接抓取正文 |
| `domain/import/models/ImportModels.ets` | 数据结构定义 |
| `pages/ImportFragment.ets` | 导入入口页面 |

### 4.2 修改文件

| 文件 | 改动 |
|------|------|
| `viewmodel/TimelineViewModel.ets` | 新增 `importCandidates` 状态与确认方法 |
| `pages/Index.ets` | 新增导入入口按钮 |

---

## 5. 数据结构

```typescript
// ImportModels.ets

export type ImportSourceType = 'TEXT' | 'OCR' | 'LINK';

export interface ImportCandidate {
  id: string;
  name: string;              // 识别出的地点名
  duration: number;          // 建议时长（分钟），可编辑
  itemType: number;          // 0=景点 1=美食 2=住宿
  rawText: string;           // 原始片段，供用户核对
  confidence: number;        // 0-1，识别置信度
  confirmed: boolean;        // 用户是否确认
}

export interface ImportSession {
  source: ImportSourceType;
  rawInput: string;
  candidates: ImportCandidate[];
  createdAt: number;
}
```

---

## 6. 分阶段实施

### Phase A：文字片段解析

**目标**：粘贴一段文字，输出结构化候选项列表。

**实现**：`FragmentParserService.parse(text)` → `ImportCandidate[]`

解析策略（优先级递减）：
1. 调用 AI（复用 `AiService`），prompt 要求输出 `[{name, duration, type}]`
2. 正则兜底：提取中文地名 + 数字时长

**约束**：
- AI 调用失败不抛出，降级到正则
- 单次解析上限 20 个候选项

**交付物**：
- `FragmentParserService` 单测通过
- 覆盖：正常文字、无地名文字、AI 失败降级

---

### Phase B：链接导入

**目标**：粘贴链接，抓取正文关键段落后走 Phase A 解析。

**实现**：`LinkFetchService.fetch(url)` → `string`（正文摘要）

- 使用 `HttpRequestHelper` 抓取页面
- 提取 `<title>` + `<p>` 标签文字，截取前 1000 字符
- 结果传入 `FragmentParserService.parse()`

**约束**：
- 超时 10 秒，失败返回空字符串（不阻断流程）
- 不存储原始 HTML

**交付物**：
- 链接导入可走通完整解析链路

---

### Phase C：截图 OCR

**目标**：选择截图，提取文字后走 Phase A 解析。

**实现**：
- 调用 HarmonyOS `TextRecognition` Kit 提取图片文字
- 结果传入 `FragmentParserService.parse()`

**约束**：
- OCR 失败给出可读提示，不崩溃
- 仅处理本地图片，不上传

**交付物**：
- OCR → 解析链路可走通

---

### Phase D：确认与写入

**目标**：用户逐条确认候选项后，一键写入时间轴。

**ViewModel 新增**：
```typescript
importSession: ImportSession | null
startImport(source: ImportSourceType, input: string): Promise<void>
confirmCandidate(id: string, edits?: Partial<ImportCandidate>): void
rejectCandidate(id: string): void
commitImport(): Promise<void>   // 将 confirmed=true 的项写入时间轴
```

**页面**：
- 候选项列表，每项可编辑 name / duration / itemType
- 全选 / 逐条确认
- 确认后调用 `commitImport()`

---

### Phase E：测试与门禁

**测试文件**：
- `entry/src/test/FragmentParserService.test.ets`
- `entry/src/test/ImportViewModel.test.ets`

**门禁**：
- `./scripts/ci/unit-all.ps1` 全量通过

---

## 7. 稳定性约束

- AI 解析失败必须降级，不阻断导入流程
- 写入时间轴复用现有 `EventRepositoryImpl.insertEvent`，不绕过
- 导入操作可撤销（写入前生成 undoToken）
- 日志前缀：`IMPORT_TRACE`

---

## 8. 执行顺序

1. Phase A — 文字解析（核心能力）
2. Phase B — 链接导入
3. Phase C — 截图 OCR
4. Phase D — 确认与写入
5. Phase E — 测试门禁

---

## 9. 完成定义（DoD）

- [ ] 文字片段可解析出地点候选项
- [ ] 链接导入可走通抓取→解析链路
- [ ] 截图 OCR 可提取文字并解析
- [ ] 用户可逐条确认/编辑后一键写入
- [ ] AI 失败场景有正则兜底，不崩溃
- [ ] 写入可撤销
- [ ] 单测覆盖解析与写入两层
