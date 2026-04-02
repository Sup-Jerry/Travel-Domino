# Secret Rotation & Incident Runbook

本手册用于处理“秘密泄露或疑似泄露”场景，覆盖发现、轮换、验证、历史清理与团队同步。

## 1. 触发条件

满足任一条件即进入应急流程：
- 明文密码、密钥、签名口令、证书、token 被提交到 Git（含历史）。
- 在日志、截图、CI 输出中出现敏感值。
- 第三方平台告警凭证泄露。

## 2. 15 分钟内动作（T+15min）

1. 暂停相关发布流水线（避免继续扩散）。
2. 锁定泄露面：记录泄露文件、提交哈希、分支、时间窗口。
3. 立即在平台侧执行轮换：
   - HarmonyOS 签名材料（storePassword/keyPassword/证书链）
   - `JWT_SECRET`
   - `DB_PASSWORD`
   - 第三方 API Keys（AI/地图等）
4. 旧值失效：在平台或服务端确认禁用旧凭据。

## 3. 轮换执行清单

- 签名相关
  - 生成新签名材料并更新安全存储（本地安全目录/CI Secret）。
  - 更新环境变量：`SIGN_STORE_FILE` `SIGN_STORE_PASSWORD` `SIGN_KEY_ALIAS` `SIGN_KEY_PASSWORD` `SIGN_PROFILE_FILE` `SIGN_CERT_PATH`。
  - 运行 `scripts/ci/generate-build-profile.ps1` 生成本地 `build-profile.json5`。
- 后端相关
  - 更新 `DB_PASSWORD`、`JWT_SECRET`。
  - 更新 CI Secret 与部署平台变量。
  - 重启相关服务并验证登录/刷新 token。
- 客户端配置
  - 更新 `AI_API_KEY` `AMAP_WEB_API_KEY` `AMAP_SDK_API_KEY` `AUTH_API_BASE_URL`。
  - 运行 `scripts/ci/generate-app-config.ps1` 生成本地 `AppConfig.ets`。

## 4. 验证标准

- `powershell -ExecutionPolicy Bypass -File scripts/ci/secret-scan.ps1 -Scope Repo` 返回通过。
- CI `security-gate` 通过。
- 关键路径回归通过：客户端启动、登录、地图搜索、后端认证接口。
- 旧 token 在策略窗口后不可再用（或立即失效策略已生效）。

## 5. Git 历史清理（git filter-repo）

> 历史清理会重写提交历史，必须提前通知团队并冻结主干合并窗口。

1. 安装 `git filter-repo`。
2. 在镜像副本仓库执行清理（示例）：

```bash
git clone --mirror <repo-url> repo-mirror.git
cd repo-mirror.git
git filter-repo --path build-profile.json5 --invert-paths
git filter-repo --path entry/src/main/ets/common/utils/AppConfig.ets --invert-paths
```

3. 如需按字符串清理，再追加 `--replace-text` 规则文件。
4. 校验历史后，强推：

```bash
git push --force --all
git push --force --tags
```

## 6. 团队同步说明（历史重写后）

所有成员执行以下任一方式：

- 推荐：重新克隆仓库。
- 或在现有本地仓库执行：

```bash
git fetch --all --prune
git checkout main
git reset --hard origin/main
```

> 注意：重置前先备份个人未合并工作。

## 7. 防复发要求（强制）

- 仅提交模板：`.env.example`、`build-profile.template.json5`、`AppConfig.template.ets`。
- 真实值仅来自环境变量注入。
- 本地启用 hooks：`powershell -ExecutionPolicy Bypass -File scripts/ci/install-git-hooks.ps1`。
- PR/Push 到 `main` 必须通过 `security-gate`。
