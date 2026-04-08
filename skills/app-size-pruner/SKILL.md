---
name: app-size-pruner
description: Clean oversized application workspaces by scanning removable large files and deleting safe, non-tracked artifacts. Use when the user says the app/project folder is too large, asks to free disk space, requests cleanup of build/cache/log/temp files, or asks for automatic deletion of disposable files.
---

# App Size Pruner

执行可重复的“体积清理”流程，优先删除可再生产物（构建输出、缓存、日志、临时文件），并自动跳过 Git 已跟踪文件与版本控制目录，降低误删风险。

## Workflow

1. 解析用户目标目录（默认当前目录），确认是“清理空间”请求。
2. 运行 `scripts/prune_large_app.ps1` 先预览候选项。
3. 如果用户明确要求“直接删除/自动删除”，立刻执行同一命令并加 `-Apply`。
4. 汇报删除数量、释放空间、失败项和报告文件路径。

## Default Commands

- 预览扫描（不删除）：
  - `powershell -ExecutionPolicy Bypass -File "<skill-dir>\\scripts\\prune_large_app.ps1" -Root "<project-root>" -MinSizeMB 20 -Top 200`
- 直接删除（用户明确要求自动删除时默认使用）：
  - `powershell -ExecutionPolicy Bypass -File "<skill-dir>\\scripts\\prune_large_app.ps1" -Root "<project-root>" -MinSizeMB 20 -Top 200 -Apply`

将 `<skill-dir>` 替换为本技能目录路径；`<project-root>` 替换为要清理的项目根目录。

## Safety Rules

- 只删除命中“安全目录/安全后缀”的文件，规则见 [cleanup-rules.md](references/cleanup-rules.md)。
- 自动跳过 `.git/.svn/.hg` 内所有文件。
- 若目标目录是 Git 仓库，自动跳过所有 Git 已跟踪文件。
- 无法确认是否可删时，不扩展删除范围；只按现有白名单执行。

## Output Contract

- 在删除模式下，必须输出：
  - 删除文件数
  - 释放空间（MB）
  - 失败数
  - JSON 报告路径（`.app-size-prune-report-*.json`）

## User-Learned Best Practices & Constraints

> **Auto-Generated Section**: This section is maintained by `skill-evolution-manager`. Do not edit manually.

### User Preferences
- When user asks to clean project, run preview first and explicitly explain MinSizeMB threshold impact before apply.
- When user reports remaining size after cleanup, provide top directory size breakdown first, then offer safe second pass.
- 瘦身默认先预览再执行删除，并回报释放空间和JSON报告路径。
- 用户要求瘦身时，先preview后apply，并在结果里给出释放空间与报告路径。
- 瘦身后若还要上传Git，优先提交代码与配置变更，不提交临时清理报告。

### Known Fixes & Workarounds
- Default MinSizeMB 20 can miss many 1-20MB build artifacts; run a second scan with MinSizeMB 1 for safe whitelist cleanup when user still needs more space.
- After cleanup, explicitly explain that .git and dependency folders such as oh_modules or node_modules are expected remaining size and are not safe-garbage targets by default.
- 瘦身执行后若释放不足，按规则降阈值二次扫描（例如MinSizeMB从20降到1）并分别汇报两轮结果。
- 当项目仍需继续开发时，清理范围优先限定为可再生产物和缓存目录。

### Custom Instruction Injection

app-size-pruner流程固定为 preview -> apply -> 结果核对，避免直接盲删。