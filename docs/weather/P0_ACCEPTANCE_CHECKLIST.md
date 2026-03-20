# 天气 Phase5 P0 验收清单

## 1. 门禁命令
- `./hvigorw.bat -p product=default assembleHap`
- `powershell -ExecutionPolicy Bypass -File scripts/ci/weather-p0-min.ps1`
- `powershell -ExecutionPolicy Bypass -File scripts/ci/weather-baseline-split.ps1`

## 2. 核心验收场景
- 怕雨高敏感：降雨条件下建议等级高于低敏感档，且文案含偏好解释。
- 耐热高容忍：高温条件下优先短停留建议，不应过度跳过节点。
- 候选为空降级：`REPLACE_NODE` 自动降级到 `REORDER/SHORTEN`，主流程不阻断。
- 天气异常降级：天气接口失败时显示“天气未知”，执行提醒链路仍可继续。
- 仅建议不自动执行：所有建议均需用户确认，不自动重排/替代。

## 3. 关键日志关键词
- `[WEATHER_PREF]`
- `[WEATHER_EXEC]`
- `[WEATHER_REPLAN]`
- `[WEATHER_CTX]`
- `[WEATHER][getWeather]`

## 4. 证据记录模板
- 日期：
- 构建版本（commit）：
- 门禁1结果（通过/失败）：
- 门禁2结果（通过/失败）：
- 门禁3结果（新增失败数 / 历史失败数）：
- 关键日志片段：
- 结论（通过/不通过）：
