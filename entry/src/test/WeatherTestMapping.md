# 天气功能测试用例映射

更新时间：2026-03-22

## 规划阶段测试
- TC-001: 规划阶段按计划地点获取天气 -> `WeatherExecution.test.ets`
- TC-002: 规划阶段不依赖当前位置 -> `WeatherPolicyResolver.test.ets`
- TC-003: 规划阶段天气提示生成 -> `WeatherRiskEvaluator.test.ets`

## 执行阶段测试
- TC-005: 执行阶段获取当前位置天气 -> `WeatherExecution.test.ets`
- TC-006: 位置变化触发刷新 -> `PlanStateMachineLink.test.ets` / `WeatherStrategyLinkage.test.ets`
- TC-007: 轮询调度器按阶段分档 -> `WeatherStageCoordinator.test.ets`

## 降级与异常测试
- TC-012: 天气接口失败降级 -> `WeatherFacade.test.ets`
- TC-013: 定位失败降级 -> `WeatherExecution.test.ets`
- TC-014: 缓存命中验证 -> `WeatherCache.test.ets`

## 性能与约束测试
- TC-016: 按城市聚合最多 5 城 -> `WeatherCityCap.test.ets`
- TC-017: 批量请求去重 -> `WeatherFacade.test.ets`

## 集成测试
- TC-019: 完整规划流程 -> `TimelineWeatherLinkageIntegration.test.ets`
- TC-020: 完整执行流程 -> `TimelineWeatherLinkageIntegration.test.ets`

## P0/P1新增链路补充
- TC-021: 状态机位移阈值触发位置事件（>=120m）-> `PlanStateMachineLink.test.ets`
- TC-022: 极端天气建议生成（SKIP_NODE）-> `WeatherExecution.test.ets`
- TC-023: 高温建议生成（SHORTEN_STAY）-> `WeatherExecution.test.ets`
- TC-024: 降雨建议生成（REORDER）-> `WeatherExecution.test.ets`

