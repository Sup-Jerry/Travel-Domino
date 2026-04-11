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
- 用户要求瘦身时默认执行preview->apply->结果证据，并在同轮回报报告路径。
- 当用户把瘦身放在复盘之后时，严格保持顺序：先沉淀再瘦身再发布。
- 用户要求代码瘦身时，默认执行 preview -> apply，并在同轮回报删除数、释放空间与 JSON 报告路径。
- 瘦身前先确认 git 状态，避免误删本轮新增未跟踪文件。
- 当瘦身紧跟复盘任务时，严格在复盘沉淀完成后再执行清理。
- 用户要求瘦身时默认执行两阶段：先 MinSizeMB=20 预览，若无候选再降到 1 做安全二次扫描。
- 瘦身阶段需与上传阶段解耦，清理报告用于回执，不默认纳入提交文件。

### Known Fixes & Workarounds
- Default MinSizeMB 20 can miss many 1-20MB build artifacts; run a second scan with MinSizeMB 1 for safe whitelist cleanup when user still needs more space.
- After cleanup, explicitly explain that .git and dependency folders such as oh_modules or node_modules are expected remaining size and are not safe-garbage targets by default.
- 瘦身执行后若释放不足，按规则降阈值二次扫描（例如MinSizeMB从20降到1）并分别汇报两轮结果。
- 在脏工作区执行瘦身前先确认Git未跟踪/已跟踪状态，避免把测试新增文件误删。
- 瘦身结果需要同时回报删除数量、释放空间和JSON报告文件。
- 若首轮清理释放不足，可在安全规则不变前提下再降 MinSizeMB 做第二轮扫描。
- 清理结果必须保留 .app-size-prune-report-*.json 作为可审计证据。
- 在单测高频执行后，优先清理 .tmp 和 build-logs 中 safe-extension 日志文件以快速回收空间。
- 执行 apply 后必须回传删除数量、释放空间与 .app-size-prune-report 路径。

### Custom Instruction Injection

瘦身执行模板：preview(20MB) -> preview/apply(1MB, 如需要) -> 汇总释放空间与报告路径。