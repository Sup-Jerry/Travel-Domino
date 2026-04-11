# Travel Domino

> README 版本：**2.1**  
> 文档更新时间：**2026-04-10**  
> 说明：本 README 按仓库 `E:\Travel` 当前代码与脚本现状编写。

## 项目概览
Travel Domino 是一个面向 HarmonyOS 的行程规划项目，当前仓库由两部分组成：

- `entry/` + `AppScope/`：HarmonyOS 客户端（ArkTS/ArkUI）
- `backend/`：NestJS + PostgreSQL 认证后端子项目

客户端目标是围绕“时间线排程 + 地图选点 + 天气联动 + 到达提醒 + 账号体系”提供旅行计划管理体验。

## 当前状态（以代码为准）

### 客户端（HarmonyOS）
已存在的关键页面（来自 `entry/src/main/resources/base/profile/main_pages.json`）：

- `Index`、`PlanListPage`、`PlanSearchPage`
- `MapPickerPage`
- `MyPage`
- `SettingsPage` 及多个子设置页
- `TrashPage`、`ArchivePage`
- `AuthGatePage`、`LoginPage`

已存在的关键能力代码（按目录）：

- 时间线与排程：`domain/timeline`、`domain/solver`、`domain/statemachine`
- 地图与位置：`infrastructure/services/AmapService.ets`、`AmapWeatherService.ets`
- 天气联动：`domain/services/Weather*`、`viewmodel/coordinators/TimelineWeatherCoordinator.ets`
- 认证与会话：`infrastructure/auth/*`
- 导入导出与提醒：`PlanImportExportService.ets`、`ArrivalReminder*`

### 后端（NestJS）
当前实际 Controller 只有 2 个：

- `@Controller('auth')`
- `@Controller('admin-health')`

`auth` 当前代码中可见接口：

- `POST /auth/guest/create`
- `POST /auth/social/login`
- `GET /auth/me`
- `PATCH /auth/profile/username`
- `PATCH /auth/profile/avatar`
- `POST /auth/profile/avatar`（兼容）
- `POST /auth/profile/username`（兼容）

健康检查接口：

- `GET /admin-health`

后端还存在 `risk/sms/social/audit` 模块服务实现，但尚未暴露独立 Controller。

## 技术栈与关键信息

| 维度 | 当前配置 |
| --- | --- |
| 客户端平台 | HarmonyOS（`modelVersion: 6.0.0`） |
| 客户端语言/UI | ArkTS + ArkUI |
| 客户端构建 | Hvigor |
| 地图能力 | AMap Harmony SDK（`@amap/amap_lbs_*`） |
| 后端 | NestJS 10 + PostgreSQL |
| 仓库包管理 | ohpm（客户端）+ npm（后端） |

应用基础信息（`AppScope/app.json5`）：

- `bundleName`: `com.jerry.travel`
- `versionName`: `1.0.0`
- `versionCode`: `1000000`

> 注意：上面的应用版本是工程 manifest 版本；本 README 文档版本为 2.1。

## 仓库结构

```text
E:\Travel
├─ entry/                    # HarmonyOS 客户端主模块
│  ├─ src/main/ets/          # 页面、领域、服务、ViewModel
│  ├─ src/test/              # 客户端单元测试
│  └─ src/ohosTest/          # 设备侧测试
├─ AppScope/                 # 应用级配置与资源
├─ backend/                  # NestJS 认证后端
│  ├─ src/modules/           # auth/health/risk/sms/social/audit
│  ├─ migrations/            # 数据库初始化 SQL
│  └─ test/                  # 后端测试
├─ scripts/ci/               # 质量门禁、构建与安全扫描脚本
├─ .githooks/                # commit-msg / pre-commit / pre-push
└─ docs/                     # 安全、重构、质量等文档
```

## 快速开始

### 1) 准备环境

客户端：

- DevEco Studio（含 HarmonyOS SDK）
- Windows PowerShell（用于脚本）

后端：

- Node.js + npm
- PostgreSQL

### 2) 配置环境变量（必须）

建议把真实密钥文件放到仓库外（仓库内仅保留 `.env.example`）：

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.travel-domino\secrets" | Out-Null
Copy-Item .env.example "$HOME\.travel-domino\secrets\travel.env"
$env:TRAVEL_ENV_FILE = "$HOME\.travel-domino\secrets\travel.env"
```

如果你仓库里已经有 `.env`，可一键迁移到仓库外并自动写入用户级环境变量：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ci/move-env-outside-repo.ps1
```

生成客户端运行配置（会写入 `entry/src/main/ets/common/utils/AppConfig.ets`）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ci/generate-app-config.ps1
```

如需签名构建，再生成签名配置（会写入 `build-profile.json5`）：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ci/generate-build-profile.ps1
```

### 3) 启动客户端

推荐直接用 DevEco Studio 打开项目运行。

如需命令行构建（Debug HAP）：

```powershell
cmd /c "entry\hvigorw.bat --no-daemon --mode module -p module=entry -p product=default -p buildMode=debug assembleHap"
```

### 4) 启动后端

```powershell
cd backend
npm install
npm run start:dev
```

首次初始化数据库：

```powershell
npm run migrate:init
```

后端最小必需环境变量：

- `DATABASE_URL`
- `JWT_SECRET`

## 测试与质量门禁

当前测试规模（仓库统计）：

- 客户端单元测试：`35` 个 `*.test.ets`
- 客户端设备侧测试：`4` 个 `*.test.ets`
- 后端测试：`2` 个 `*.spec.ts`

常用检查命令：

```powershell
# 机密扫描（仓库范围）
powershell -ExecutionPolicy Bypass -File scripts/ci/secret-scan.ps1 -Scope Repo

# 客户端质量门禁（含构建与 ArkTS warn budget）
powershell -ExecutionPolicy Bypass -File scripts/ci/quality-gate.ps1

# 客户端单测全集
powershell -ExecutionPolicy Bypass -File scripts/ci/unit-all.ps1

# 全门禁（quality + unit）
powershell -ExecutionPolicy Bypass -File scripts/ci/full-gate.ps1
```

天气专项门禁入口：

```powershell
scripts\weather_p0_gate.bat
```

CI（GitHub Actions）：

- `.github/workflows/security-gate.yml`
- 触发条件：`main` 分支 push / PR
- 当前执行：`scripts/ci/secret-scan.ps1`

## Git 协作与发布约定

安装本地 hooks：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ci/install-git-hooks.ps1
```

项目默认发布入口：

```powershell
./scripts/git-auto-publish.ps1 -Message "<提交信息>"
```

常见参数：

- 只提交指定文件：`-Files "path/a","path/b"`
- 只本地提交不推送：`-NoPush`
- 推送但不创建 PR：`-NoPR`

治理约束（已在脚本与 hook 中落地）：

- 默认禁止直推 `main`
- 必须走 `develop / feature/* / release/* / hotfix/*`

## 安全说明

- 不要提交任何真实密钥、证书、签名文件、`.env`。
- 可提交模板：`.env.example`、`build-profile.template.json5`、`AppConfig.template.ets`。
- 已加入忽略：`AppConfig.ets`、`build-profile.json5`、`.env`、证书类文件（`.p12/.p7b/.cer/...`）。

密钥轮换与历史清理参考：

- `docs/security/secret-rotation-runbook.md`

## 已知边界

- 后端 README 中包含部分目标态接口；协作时请以 `backend/src/modules/*/*.controller.ts` 为准。
- 客户端功能范围请以 `entry/src/main/ets/` 当前实现为准。

## License

当前仓库根目录未声明开源许可证；如需开源，请先补充 `LICENSE` 文件。
