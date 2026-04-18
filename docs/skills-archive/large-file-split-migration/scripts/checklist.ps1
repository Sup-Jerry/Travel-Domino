param(
  [Parameter(Mandatory = $true)]
  [string]$ModuleName,

  [Parameter(Mandatory = $true)]
  [string]$SourceFile,

  [string]$OutputFile = "./migration-$($ModuleName.ToLower()).md"
)

$targetFile = "<target-path-for-$ModuleName>"

$content = @"
## 拆分目标
从 `$SourceFile` 中提取 `$ModuleName` 到 `$targetFile`。
本轮不修改：业务逻辑、返回结构、UI行为、存储策略。

## 单一职责
仅负责：

## 输入
- 

## 输出
- 

## 依赖
- 

## 副作用
- 

## 迁移清单
### 方法
- [ ]
- [ ]
- [ ]

### 常量 / 类型 / 默认值
- [ ]
- [ ]

### 错误处理 / 日志 / 状态写入
- [ ]
- [ ]

## 调用点替换
- [ ] 
- [ ] 

## 验证场景
- [ ] 主流程
- [ ] 边界输入
- [ ] 冲突输入
- [ ] 默认值触发
- [ ] 副作用检查

## 完成条件
- [ ] 行为等价
- [ ] 调用点替换完成
- [ ] 旧逻辑可删除
- [ ] 回归通过
"@

Set-Content -Path $OutputFile -Value $content -Encoding UTF8
Write-Host "Generated: $OutputFile"
