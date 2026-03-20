# 天气 TC 追踪矩阵（Phase5 闭环）

结构层调用链：`TimelineViewModel -> WeatherFacade -> WeatherDomainService -> WeatherContextBuilder / AmapWeatherService`

| TC | 覆盖方式 | 对应实现/测试 | 备注 |
| --- | --- | --- | --- |
| TC-001 | 自动化 | `WeatherCityCap.test.ets` + `WeatherExecution.test.ets` | 规划态按计划点位取天气 |
| TC-002 | 手工 | 规划页跨城场景验收 | 规划态不依赖当前位置 |
| TC-003 | 自动化 | `WeatherRiskEvaluator.test.ets` | 规划提示与风险评分 |
| TC-004 | 手工 | 不同天气下排序对比 | 软约束排序参考 |
| TC-005 | 自动化 | `WeatherExecution.test.ets` | 执行态当前位置天气 |
| TC-006 | 自动化 | `WeatherExecution.test.ets` | 执行态下一/后续节点天气 |
| TC-007 | 自动化 | `WeatherExecution.test.ets` | 执行态提醒触发 |
| TC-008 | 自动化 | `WeatherExecution.test.ets` | 执行态刷新链路 |
| TC-009 | 手工 | 执行态 UI 验收 | 展示一致性 |
| TC-010 | 手工 | 规划页 UI 验收 | Banner/节点文案 |
| TC-011 | 手工 | 弱网/无网验收 | 降级与兜底 |
| TC-012 | 手工 | 缓存命中观察 | 请求去重 |
| TC-013 | 自动化 | `WeatherCache.test.ets` | 缓存命中/过期 |
| TC-014 | 手工 | 手动刷新验收 | 强刷绕过缓存 |
| TC-015 | 手工 | 失败降级验收 | 天气未知不阻断 |
| TC-016 | 手工 | 多节点异常验收 | 部分失败仍可用 |
| TC-017 | 手工 | 规划-执行切换验收 | 阶段切换稳定 |
| TC-018 | 自动化 | `WeatherStageCoordinator.test.ets` | 分档轮询策略 |
| TC-019 | 自动化 | `WeatherExecution.test.ets` | 执行链路不中断 |
| TC-020 | 自动化 | `WeatherCityCap.test.ets` | 多城聚合上限（5城） |
