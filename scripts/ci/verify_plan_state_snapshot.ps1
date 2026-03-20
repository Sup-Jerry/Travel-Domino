param(
  [Parameter(Mandatory = $true)]
  [string]$SnapshotPath
)

if (!(Test-Path $SnapshotPath)) {
  Write-Error "Snapshot file not found: $SnapshotPath"
  exit 1
}

$raw = Get-Content -Path $SnapshotPath -Raw -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($raw)) {
  Write-Error "Snapshot file is empty."
  exit 1
}

try {
  $snapshot = $raw | ConvertFrom-Json
} catch {
  Write-Error "Snapshot JSON parse failed: $($_.Exception.Message)"
  exit 1
}

if (-not $snapshot.metrics -or -not $snapshot.metrics.counters) {
  Write-Error "Snapshot missing metrics.counters."
  exit 1
}

$c = $snapshot.metrics.counters
function GetCounter([string]$key) {
  if ($null -eq $c.$key) { return 0 }
  return [int]$c.$key
}

$readyAttempt = GetCounter "auto_transition_attempt_ready"
$readySuccess = GetCounter "auto_transition_success_ready"
$readyFail = GetCounter "auto_transition_fail_ready"
$inAttempt = GetCounter "auto_transition_attempt_in_progress"
$inSuccess = GetCounter "auto_transition_success_in_progress"
$inFail = GetCounter "auto_transition_fail_in_progress"
$recoveryAttempt = GetCounter "recovery_attempt"
$recoverySuccess = GetCounter "recovery_success"
$recoveryFail = GetCounter "recovery_fail"
$jitterBlocked = GetCounter "transition_jitter_blocked"

$errors = @()
if ($readyAttempt -lt ($readySuccess + $readyFail)) {
  $errors += "ready bucket mismatch: attempt < success+fail"
}
if ($inAttempt -lt ($inSuccess + $inFail)) {
  $errors += "in_progress bucket mismatch: attempt < success+fail"
}
if ($recoveryAttempt -lt ($recoverySuccess + $recoveryFail)) {
  $errors += "recovery bucket mismatch: attempt < success+fail"
}
if ($jitterBlocked -lt 0) {
  $errors += "jitter_blocked must be >= 0"
}

if ($errors.Count -gt 0) {
  Write-Error ("Snapshot verification failed: " + ($errors -join "; "))
  exit 1
}

Write-Host "Snapshot verification passed."
Write-Host "ready: $readyAttempt/$readySuccess/$readyFail"
Write-Host "in_progress: $inAttempt/$inSuccess/$inFail"
Write-Host "recovery: $recoveryAttempt/$recoverySuccess/$recoveryFail"
Write-Host "jitter_blocked: $jitterBlocked"
