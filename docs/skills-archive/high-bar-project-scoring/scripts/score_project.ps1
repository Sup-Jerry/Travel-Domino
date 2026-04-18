param(
  [Parameter(Mandatory = $false)]
  [string]$ProjectRoot = '',

  [Parameter(Mandatory = $false)]
  [ValidateSet('H1', 'H2', 'H3', 'H4')]
  [string]$Strictness = 'H4'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
  $ProjectRoot = (Get-Location).Path
}

function Run-Cmd {
  param(
    [Parameter(Mandatory = $true)][string]$Cmd,
    [Parameter(Mandatory = $false)][string]$Cwd = $ProjectRoot
  )
  Push-Location $Cwd
  try {
    $out = Invoke-Expression $Cmd 2>&1
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    return [PSCustomObject]@{
      Command = $Cmd
      ExitCode = $code
      Output = @($out)
    }
  } finally {
    Pop-Location
  }
}

$timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
$results = @()

$results += Run-Cmd -Cmd 'git status -sb'
$results += Run-Cmd -Cmd 'rg --files'
$results += Run-Cmd -Cmd 'rg --files entry/src/test'
$results += Run-Cmd -Cmd 'rg --files backend/test'
$results += Run-Cmd -Cmd 'rg -n "TODO|FIXME|HACK" entry backend docs README.md'
$results += Run-Cmd -Cmd 'git ls-files .env build-profile.json5 entry/src/main/ets/common/utils/AppConfig.ets'

$reportPath = Join-Path $ProjectRoot (".tmp\project-score-draft-{0}.md" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path (Split-Path $reportPath -Parent) -Force | Out-Null

$lines = @()
$lines += "# Project Scoring Draft"
$lines += ""
$lines += "- Timestamp: $timestamp"
$lines += "- Strictness: $Strictness"
$lines += "- ProjectRoot: $ProjectRoot"
$lines += ""
$lines += "## Command Evidence"

foreach ($r in $results) {
  $lines += ""
  $lines += ('### "{0}"' -f $r.Command)
  $lines += "- ExitCode: $($r.ExitCode)"
  $lines += '```text'
  if ($r.Output.Count -eq 0) {
    $lines += "[no output]"
  } else {
    $lines += $r.Output
  }
  $lines += '```'
}

$lines += ""
$lines += "## Scoring Skeleton (manual fill required)"
$lines += "- Total: __ / 100"
$lines += "- Grade: __"
$lines += "- Level: $Strictness"
$lines += ""
$lines += "### Dimension Breakdown"
$lines += "- Architecture and boundaries: __ / 20"
$lines += "- Code quality and complexity: __ / 20"
$lines += "- Test and regression confidence: __ / 20"
$lines += "- Engineering and release gates: __ / 15"
$lines += "- Security and configuration governance: __ / 15"
$lines += "- Documentation and collaboration: __ / 10"
$lines += ""
$lines += "### Top 5 Deductions"
$lines += "1. observation -> evidence -> risk -> deduction"
$lines += "2. observation -> evidence -> risk -> deduction"
$lines += "3. observation -> evidence -> risk -> deduction"
$lines += "4. observation -> evidence -> risk -> deduction"
$lines += "5. observation -> evidence -> risk -> deduction"
$lines += ""
$lines += "### Cap Rule Status"
$lines += "- Triggered caps: __"
$lines += "- Applied cap: __"
$lines += "- Reason: __"
$lines += ""
$lines += "### Confidence"
$lines += "- high / medium / low: __"
$lines += "- Why: __"
$lines += ""
$lines += "### Top 3 Actions"
$lines += "1. __"
$lines += "2. __"
$lines += "3. __"

Set-Content -Path $reportPath -Value $lines -Encoding UTF8
Write-Host "[score-project] draft generated: $reportPath"
