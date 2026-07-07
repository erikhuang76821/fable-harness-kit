# Benchmark 執行器:同一任務 × 兩臂(裸 Fable / kit 化 Opus),收驗收+成本+時間
# 協議見 PROTOCOL.md(預註冊)。用法:
#   powershell -File benchmark\run-benchmark.ps1 -Tasks T1            # pilot
#   powershell -File benchmark\run-benchmark.ps1                      # 全套 T1-T4
# 結果:benchmark\results\results-<stamp>.jsonl(每 run 一行);workdir artifact 留在 %TEMP%

param(
  [string[]]$Tasks = @('T1', 'T2', 'T3', 'T4'),
  # 臂:fable(裸 Fable 5)/ kit(kit 化 Opus)/ opus(裸 Opus,消融對照——測 kit 增量的 kill-switch)
  [string[]]$Arms = @('fable', 'kit'),
  [int]$Runs = 1,
  [string]$FableModel = 'claude-fable-5',
  [string]$OpusModel = 'claude-opus-4-8',
  [string]$OutRoot = (Join-Path $env:TEMP ("fable-bench-" + (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

$benchDir = $PSScriptRoot
$kitRoot = Split-Path $benchDir -Parent
$resultsDir = Join-Path $benchDir 'results'
New-Item -ItemType Directory -Force $resultsDir, $OutRoot | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$resultsFile = Join-Path $resultsDir "results-$stamp.jsonl"
# 兩臂工具白名單一致(與 fable-run 預設同步)
$AT = 'Read,Edit,Write,Glob,Grep,TodoWrite,Task,Agent,Workflow,Skill,Bash(node:*),Bash(npm:*),Bash(npx:*),Bash(git:*),Bash(ls:*),Bash(cat:*),Bash(date:*),Bash(python:*),Bash(python3:*),Bash(py:*),Bash(pytest:*)'

function Get-CostFromLogs([string[]]$logPaths) {
  # total_cost_usd 為單一行程的累計值:同一 log 取末筆,跨 log 加總(與 fable-run 同語意)
  $cost = 0.0; $in = 0; $out = 0; $has = $false
  foreach ($p in $logPaths) {
    if (-not (Test-Path $p)) { continue }
    $fileCost = $null; $fileIn = 0; $fileOut = 0
    foreach ($line in (Get-Content $p)) {
      try { $ev = $line | ConvertFrom-Json } catch { continue }
      if ($ev.type -eq 'result') {
        if ($null -ne $ev.total_cost_usd) { $fileCost = [double]$ev.total_cost_usd }
        if ($ev.usage) {
          if ($ev.usage.input_tokens) { $fileIn = [long]$ev.usage.input_tokens }
          if ($ev.usage.output_tokens) { $fileOut = [long]$ev.usage.output_tokens }
        }
      }
    }
    if ($null -ne $fileCost) { $cost += $fileCost; $has = $true }
    $in += $fileIn; $out += $fileOut
  }
  return @{ cost = $(if ($has) { [math]::Round($cost, 4) } else { $null }); in = $in; out = $out }
}

foreach ($t in $Tasks) {
  $fixture = Join-Path $benchDir "fixtures\$t"
  if (-not (Test-Path $fixture)) { Write-Error "fixture 不存在:$t"; continue }
  $task = (Get-Content (Join-Path $fixture 'task.txt') -Raw -Encoding utf8).Trim()

  foreach ($arm in $Arms) {
    for ($run = 1; $run -le $Runs; $run++) {
    $wd = Join-Path $OutRoot "$t-$arm-r$run"
    Copy-Item $fixture $wd -Recurse
    Push-Location $wd
    try {
      git init -q; git config user.name 'bench'; git config user.email 'bench@local'
      git add -A; git commit -q -m "baseline $t"
      if ($LASTEXITCODE -ne 0) { Write-Error "baseline commit 失敗:$t-$arm-r$run"; continue }

      Write-Host "===== [$t/$arm/r$run] 開跑 ====="
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      if ($arm -eq 'kit') {
        & (Join-Path $kitRoot 'init.ps1') -Target $wd | Out-Null
        git add -A; git commit -q -m 'kit files'   # kit 檔不算受測 diff
        & (Join-Path $kitRoot 'fable-run.ps1') -Task $task -Target $wd | Out-Null
        $logs = @(Get-ChildItem "$wd\.fable\run-logs\*.jsonl" -ErrorAction SilentlyContinue | ForEach-Object FullName)
      } else {
        $model = if ($arm -eq 'opus') { $OpusModel } else { $FableModel }
        $log = Join-Path $wd 'bench-fable.jsonl'
        claude -p $task --model $model --permission-mode acceptEdits --allowedTools $AT --output-format stream-json --verbose *> $log
        $logs = @($log)
      }
      $sw.Stop()

      $acceptOut = & powershell -NoProfile -File (Join-Path $wd 'ACCEPT.ps1') 2>&1
      $pass = ($LASTEXITCODE -eq 0)
      $c = Get-CostFromLogs $logs
      # scope 遙測:受測 diff 動了幾個檔(排除 kit 檔與驗收產物)——供消融比較範圍紀律
      git add -A *> $null
      $scopeFiles = @(git diff --cached HEAD --name-only -- . ':(exclude).claude' ':(exclude)CLAUDE.md' ':(exclude)CONTEXT.md' ':(exclude)docs' ':(exclude)tests' ':(exclude)scripts' ':(exclude)benchmark' ':(exclude)fable-run.ps1' ':(exclude).fable' ':(exclude).gitignore' ':(exclude)bench-fable.jsonl' ':(exclude)__pycache__' ':(exclude)*.pyc' 2>$null)

      $rec = @{
        task = $t; arm = $arm; run = $run; pass = $pass; duration_s = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        cost_usd = $c.cost; in_tokens = $c.in; out_tokens = $c.out
        files_changed = $scopeFiles.Count
        workdir = $wd; stamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
      } | ConvertTo-Json -Compress
      Add-Content -Path $resultsFile -Value $rec -Encoding utf8
      Write-Host "[$t/$arm/r$run] pass=$pass 時間=$([math]::Round($sw.Elapsed.TotalSeconds))s 成本=$($c.cost) 檔數=$($scopeFiles.Count) → $resultsFile"
    } finally { Pop-Location }
    }
  }
}

Write-Host "`n===== 彙總($resultsFile)====="
Get-Content $resultsFile -Encoding utf8 | ForEach-Object { $r = $_ | ConvertFrom-Json; "{0}/{1}: pass={2} {3}s `${4}" -f $r.task, $r.arm, $r.pass, $r.duration_s, $r.cost_usd }
Write-Host "下一步:powershell -File benchmark\judge.ps1 -ResultsFile `"$resultsFile`"(雙裁判盲評)"
