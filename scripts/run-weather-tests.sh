#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "=== 天气功能测试套件 ==="

run_hvigor_suite() {
  echo "运行 P0 核心测试（entry 模块）..."
  cmd.exe /c "cd /d E:\\Travel12.19 && hvigorw.bat --mode module -p module=entry@default -p product=default test"
}

run_npm_suite() {
  echo "运行 P0 核心测试..."
  npm test -- WeatherP0Suite.test.ets

  echo "运行集成测试..."
  npm test -- TimelineWeatherLinkageIntegration.test.ets

  echo "运行所有天气测试..."
  npm test -- --testPathPattern=Weather

  echo "生成覆盖率报告..."
  npm run test:coverage -- --testPathPattern=Weather
}

if [[ -f "$ROOT_DIR/hvigorw.bat" ]]; then
  run_hvigor_suite
elif [[ -f "$ROOT_DIR/package.json" ]]; then
  run_npm_suite
else
  echo "未找到 hvigorw.bat 或 package.json，无法执行天气测试。"
  exit 1
fi

echo "=== 天气测试执行完成 ==="

