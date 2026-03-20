# 天气 Phase5 P0 验收清单

## 1. 目标
- 验证偏好增强与替代建议在规划态/执行态可用。
- 验证建议仅为可选动作，不自动执行。
- 验证候选为空时可降级且不阻断主流程。

## 2. 预置条件
- 构建通过：`./hvigorw.bat -p product=default assembleHap`
- 已配置天气偏好（怕热/怕雨/容忍）并保存成功。
- 行程中存在至少 3 个未完成节点。

## 3. 场景清单

### A. 怕雨高敏感
- 操作：设置 `rainSensitivity=HIGH`，触发雨天建议刷新。
- 预期：
  - 规划态提示包含偏好解释。
  - 执行态优先出现室内/重排类建议。
  - 日志包含 `[WEATHER_PREF]` 与 `[WEATHER_REPLAN]` 字段。

### B. 耐热高容忍
- 操作：设置 `heatSensitivity=LOW` 且 `weatherRiskTolerance=HIGH`，触发高温建议刷新。
- 预期：
  - 高温场景不应直接过度触发跳过建议。
  - 优先给出缩短停留等轻量建议。

### C. 替代候选为空降级
- 操作：触发 `REPLACE_NODE` 场景，且候选列表为空或不足。
- 预期：
  - 自动降级到 `REORDER/SHORTEN`。
  - 日志出现 `replace_fallback`。
  - 主流程可继续，不出现阻断弹窗。

### D. 可选动作语气一致
- 检查点：
  - 规划页文案为“天气建议（可选）”。
  - 执行卡文案为“调整建议（可选）”。
  - 提醒弹窗按钮为“可选：应用建议/可选：刷新天气”。

## 4. 关键日志关键字
- `[WEATHER_PREF][load]`
- `[WEATHER_PREF][update]`
- `[WEATHER_REPLAN][refresh_begin]`
- `[WEATHER_REPLAN][refresh_done]`
- `[WEATHER_REPLAN][replace_quality]`
- `[WEATHER_REPLAN][replace_fallback]`
- `[WEATHER_REPLAN][apply_done]`

## 5. 验收结论模板
- 日期：
- 版本：
- 结果：通过 / 不通过
- 失败项：
- 证据：日志片段、截图路径、复现步骤

## 6. 建议质量指标定义（日志统计）
- 候选命中率：`replace_quality.candidates > 0` 的次数 / `REPLACE_NODE` 总触发次数
- 降级率：`replace_fallback` 次数 / `REPLACE_NODE` 总触发次数
- 应用成功率：`apply_done result=SUCCESS` 次数 / 应用尝试总次数
