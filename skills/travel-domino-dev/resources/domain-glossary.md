# 领域词汇表

## Day X
连续展示层的行程天编号，不一定等同于自然日字段本身，需结合起始日期与 day_offset 理解。

## day_offset
相对计划起始日的偏移天数，是行程跨天分组的重要依据。

## DateGroup
按日期或偏移日聚合后的展示分组结构，用于 Timeline / Day X 渲染。

## EventEntity
单个行程事件实体，可能涉及时间、地点、持续时长、优先级、所属计划等信息。

## PlanEntity
整体计划实体，包含起始日期、计划范围等全局信息。

## Backlog / 暂存池
未正式排入具体日程的候选地点/事项集合。

## TimelineViewModel
用于组织时间轴展示、分组计算、状态联动与交互分发的关键层。

## TimeConstraintSolver
处理时间约束、压缩、分配、冲突解决的核心逻辑层。

## 地图服务
涉及路线时长、通勤时间、地点搜索、地理能力；通常与 AmapService 或 MapServiceImpl 有关。
