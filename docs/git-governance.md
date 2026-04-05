# Git Governance

## 一键启用
```powershell
./scripts/setup-git-governance.ps1
```

## 一键全自动上传（唯一推荐入口）
```powershell
./scripts/git-auto-publish.ps1
```

口令触发约定（仓库内对话）：
- 当用户说“上传到github / 推到github / 发布到github”等同义口令时，默认执行 `./scripts/git-auto-publish.ps1`。
- 未特别说明时，默认保留自动 Draft PR 到 `develop`。
- 用户明确要求“不推送/不要PR/只本地提交”时覆盖默认。

默认行为：
- 禁止从 `main` 直接发布（除非显式 `-AllowMainPush`）
- 当前在 `develop` 时自动创建分支：`feature/YYYYMMDD-短描述`
- 自动 `git add -A`、自动生成提交描述并提交
- 自动推送分支
- 自动创建 Draft PR 到 `develop`

常用参数：
```powershell
./scripts/git-auto-publish.ps1 -Slug map-cache -Type fix -Scope timeline
./scripts/git-auto-publish.ps1 -NoPR
./scripts/git-auto-publish.ps1 -AllowMainPush   # break-glass only
```

## 失败处理
- `pre-push blocked: direct push to main`：切到 `develop/feature/*` 重试。
- `commit-msg invalid`：改成 `<type>[optional scope]: <description>`。
- `gh not found/authenticated`：安装并登录 `gh`，或使用 `-NoPR`。
- `console.log/TODO/大文件` 被拦截：按提示清理后重试。
