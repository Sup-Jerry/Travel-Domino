# Travel Domino

Travel Domino 是一个面向 HarmonyOS 的行程规划项目，聚焦“时间线排程 + 地图联动 + 智能辅助 + 提醒执行”的旅行计划管理体验。

## 1. 当前能力清单（按实现状态分级）

### 已实现

- HarmonyOS 客户端主流程：计划列表、计划详情、设置、搜索、归档、回收站等页面基础结构。
- 时间线核心能力：`Plan + Event` 的增删改查、冲突检测与部分冲突处理流程。
- 地图与位置基础能力：已接入高德 Harmony SDK 相关依赖，包含地图/搜索/定位服务代码。
- AI 与提醒相关模块：已存在 AI 服务、到达提醒引擎与协调器等实现入口。
- 自动化测试基础：客户端单元测试与设备测试已接入（见“测试与质量”章节）。

### 部分实现（进行中）

- 后端认证服务已落地最小闭环接口：当前代码中可见 `POST /auth/guest/create`、`GET /auth/me`。
- 后端健康检查接口可用：`GET /admin-health`。
- 客户端与后端联动能力处于迭代中，接口覆盖范围以当前控制器实现为准。

### 计划中

- 云端数据能力（跨设备同步/恢复）在仓库内有规划文档与拆解材料，但不应视为已完整交付。
- 更完整的认证方式（手机号/第三方登录等）已在后端文档中规划，当前仓库代码未全部实现。

## 2. 技术栈与仓库结构

### 技术栈

| 维度 | 方案 |
| --- | --- |
| 客户端平台 | HarmonyOS（API 20） |
| 客户端语言/UI | ArkTS + ArkUI |
| 构建 | Hvigor |
| 地图能力 | AMap Harmony SDK |
| 后端 | NestJS + PostgreSQL |

### 仓库结构（核心）

```text
E:\Travel12.19
├─ entry/                    # HarmonyOS 客户端主模块（ArkTS）
│  ├─ src/main/ets/          # 页面、领域、服务、持久化、ViewModel
│  ├─ src/test/              # 客户端单元测试
│  └─ src/ohosTest/          # 设备侧测试
├─ AppScope/                 # 应用级配置与资源
├─ backend/                  # NestJS 认证后端子项目
│  ├─ src/modules/           # auth/health 等模块
│  ├─ migrations/            # 数据库初始化 SQL
│  └─ docs/                  # 后端运维与测试跟踪文档
└─ scripts/ci/               # 质量门禁与 CI 脚本
```

## 3. 快速开始

### 客户端（HarmonyOS）

1. 环境准备
   - DevEco Studio（建议使用稳定版本）
   - HarmonyOS SDK（与项目 `6.0.0(20)` 对齐）
2. 本地配置密钥
   - 复制 `entry/src/main/ets/common/utils/AppConfig.example.ets`
   - 重命名为 `entry/src/main/ets/common/utils/AppConfig.ets`
   - 按需填写：`AI_API_KEY`、`AMAP_WEB_API_KEY`、`AMAP_SDK_API_KEY`
3. 运行方式
   - 推荐：DevEco Studio 打开项目后直接运行
   - 可选：命令行在仓库根目录执行 `hvigorw.bat` 对应任务

### 后端（NestJS）

1. 安装与启动

```bash
cd backend
npm install
npm run start:dev
```

2. 最小环境变量（当前实现必需）
   - `DATABASE_URL`
   - `JWT_SECRET`
   - 可选：`AUTH_ACCESS_TTL_SECONDS`、`AUTH_REFRESH_TTL_SECONDS`、`AUTH_USE_STUB_PROVIDERS`

## 4. 测试与质量

- 客户端单元测试目录：`entry/src/test`（当前 28 个 `.test.ets` 文件）。
- 客户端设备测试目录：`entry/src/ohosTest`（当前 4 个 `.test.ets` 文件）。
- 后端测试目录：`backend/test`（当前含基础认证相关测试）。
- 仓库含 CI/门禁脚本：`scripts/ci/`（如 `quality-gate.ps1`、`full-gate.ps1`、`secret-scan.ps1`）。

## 5. 现状说明（请在协作前先阅读）

- 本仓库为“客户端主工程 + 后端子项目并行迭代”状态。
- 后端 `backend/README.md` 中列出的部分接口仍属目标清单，不代表当前全部可用。
- 对外协作时请优先以实际代码为准：
  - 控制器位置：`backend/src/modules/*/*.controller.ts`
  - 客户端能力入口：`entry/src/main/ets/`

## 6. 安全与配置

- 严禁提交任何真实密钥、令牌、凭据。
- `entry/src/main/ets/common/utils/AppConfig.ets` 为本地私有配置，已在 `.gitignore` 中忽略。
- 若密钥泄露，请立即在服务端完成轮换，不要仅在仓库中删除明文。

## 7. License 状态

当前仓库尚未声明开源许可证。若计划公开发布，请先补充 `LICENSE` 文件并明确使用条款。
