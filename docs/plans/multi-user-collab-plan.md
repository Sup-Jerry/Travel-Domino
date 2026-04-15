# 多人协作治理实施计划

## 1. 痛点定义

**当前状态**：多人出游时，行程只能一人维护，其他人无法提议修改，也无法表达偏好冲突。

**目标状态**：支持"提案态/确认态"协作模式——任何人可发起修改提案，影响方可见并确认，偏好权重可配置，执行阶段的修改边界受控。不做泛社交，只做决策治理。

---

## 2. 成功标准

- 行程可邀请协作者（本地 planId 共享，不依赖云端实时同步）
- 修改以"提案"形式提交，发起人和影响方均可见
- 提案可被接受 / 拒绝 / 修改后再提交
- 执行阶段（行程进行中）的修改边界受限（不可改已到访事件）
- 偏好权重可配置（谁的意见优先级更高）
- 日志前缀：`COLLAB_TRACE`

---

## 3. 范围

**包含**：
- 协作者角色与权限定义
- 提案态 / 确认态工作流
- 偏好权重配置
- 执行阶段修改边界
- 提案历史记录

**不包含**：
- 实时云端同步（本期用本地 + 手动导出）
- 聊天 / 群组功能
- 推送通知

---

## 4. 核心概念

| 概念 | 说明 |
|------|------|
| Owner | 行程创建者，最终决策权 |
| Collaborator | 协作者，可提案，不可直接写入 |
| Proposal | 提案：对行程的一次修改意图 |
| AffectedParty | 提案影响到的协作者 |
| PreferenceWeight | 各协作者的偏好权重（0-10） |

---

## 5. 数据结构

```typescript
// CollabModels.ets

export type CollabRole = 'OWNER' | 'COLLABORATOR';
export type ProposalStatus = 'PENDING' | 'ACCEPTED' | 'REJECTED' | 'REVISED';
export type ProposalActionType = 'ADD' | 'REMOVE' | 'REORDER' | 'MODIFY_TIME';

export interface Collaborator {
  id: string;
  name: string;
  role: CollabRole;
  preferenceWeight: number;   // 0-10
}

export interface Proposal {
  id: string;
  proposerId: string;
  actionType: ProposalActionType;
  targetEventId?: number;
  payload: Object;            // 具体修改内容
  status: ProposalStatus;
  affectedPartyIds: string[];
  votes: ProposalVote[];
  createdAt: number;
}

export interface ProposalVote {
  collaboratorId: string;
  approved: boolean;
  comment?: string;
  votedAt: number;
}
```

---

## 6. 分阶段实施

### Phase A：角色与权限

**目标**：行程支持多协作者，角色权限隔离。

**实现**：
- `PlanRepositoryImpl` 新增协作者列表字段
- Owner 可邀请 / 移除协作者
- Collaborator 只读行程，不可直接写入事件

**交付物**：
- 角色权限单测通过（Owner 写入成功，Collaborator 写入被拦截）

---

### Phase B：提案工作流

**目标**：Collaborator 发起提案，Owner 审批后生效。

**实现**：`ProposalService`
- `submitProposal(planId, proposal)` → 写入提案列表
- `voteProposal(proposalId, vote)` → 记录投票
- `applyProposal(proposalId)` → Owner 接受后写入时间轴（复用现有 EventRepositoryImpl）
- `rejectProposal(proposalId)` → 标记拒绝，不写入

**约束**：
- 提案应用前生成 undoToken
- 执行阶段（行程进行中）不可提案修改已到访事件

**交付物**：
- 提案提交 → 投票 → 应用 / 拒绝全链路可走通

---

### Phase C：偏好权重与冲突提示

**目标**：多人偏好冲突时，系统给出权重加权建议。

**实现**：
- `ConflictResolver.resolve(proposals, collaborators)` → 推荐方案
- 权重加权：支持率 = Σ(approver.weight) / Σ(all.weight)
- 支持率 ≥ 0.6 自动标记"建议接受"，否则标记"存在分歧"

**交付物**：
- 冲突解析单测通过（含权重边界）

---

### Phase D：执行阶段修改边界

**目标**：行程进行中，限制可修改范围。

**规则**：
- 已到访事件（visitStatus=VISITED）不可提案修改
- 当前正在执行的事件只允许 Owner 直接修改
- 未来事件可正常提案

**实现**：
- `ProposalService.submitProposal` 前置校验上述规则
- 校验失败返回明确错误码

**交付物**：
- 边界校验单测通过

---

### Phase E：页面集成

**目标**：时间轴页面支持提案查看与操作。

**页面新增**：
- 协作者列表入口（行程设置页）
- 待审提案列表（Owner 视角）
- 我的提案状态（Collaborator 视角）
- 提案详情：修改内容 + 投票情况 + 接受/拒绝操作

---

### Phase F：测试与门禁

**测试文件**：
- `entry/src/test/ProposalService.test.ets`
- `entry/src/test/ConflictResolver.test.ets`

**门禁**：
- `./scripts/ci/unit-all.ps1` 全量通过

---

## 7. 稳定性约束

- Collaborator 任何操作不可绕过提案直接写入时间轴
- 提案应用失败自动回滚（undoToken 保护）
- 已到访事件不参与任何提案修改
- 本期不依赖云端同步，协作数据存本地

---

## 8. 执行顺序

1. Phase A — 角色与权限
2. Phase B — 提案工作流
3. Phase C — 偏好权重与冲突提示
4. Phase D — 执行阶段修改边界
5. Phase E — 页面集成
6. Phase F — 测试门禁

---

## 9. 完成定义（DoD）

- [ ] Owner / Collaborator 权限隔离生效
- [ ] 提案提交 → 投票 → 应用 / 拒绝全链路可走通
- [ ] 偏好权重加权冲突提示可生成
- [ ] 执行阶段已到访事件不可被提案修改
- [ ] 提案应用失败可回滚
- [ ] 单测覆盖提案工作流与冲突解析
