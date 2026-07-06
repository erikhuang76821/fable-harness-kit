# fable-run:headless Tier 2/3 的監督式執行器(防 headless 截斷背景 workflow)
# 機制:跑 claude -p → 行程結束後讀 .fable TASK.md 狀態 → 非終態 = 被截斷 → --continue 以 resumeFromRunId 續跑
# 用法:powershell -File fable-run.ps1 -Task "任務描述" [-Target <dir>] [-MaxResumes 2]

param(
  [Parameter(Mandatory = $true)][string]$Task,
  [string]$Target = (Get-Location).Path,
  [string]$Model = 'claude-opus-4-8',
  [int]$MaxResumes = 2,
  [string]$AllowedTools = 'Read,Edit,Write,Glob,Grep,TodoWrite,Task,Agent,Workflow,Skill,Bash(node:*),Bash(npm:*),Bash(npx:*),Bash(git:*),Bash(ls:*),Bash(cat:*),Bash(date:*),Bash(python:*),Bash(python3:*),Bash(py:*),Bash(pytest:*)'
)

# 終態清單以 .claude/status-contract.json 為單一來源(執行期載入);下列硬編碼僅為契約檔缺失時的後備
$terminal = @('done', 'done_with_gaps', 'blocked', 'blocked_on_review', 'budget_exhausted',
              'needs_user_input', 'needs_user_decision', 'review_unavailable', 'process_mismatch',
              'failed', 'winner_selected', 'no_qualified_winner')
$contractPath = Join-Path $Target '.claude\status-contract.json'
if (Test-Path $contractPath) {
  try {
    $loaded = @((Get-Content $contractPath -Raw -Encoding utf8 | ConvertFrom-Json).terminal)
    if ($loaded.Count -gt 0) { $terminal = $loaded }
  } catch { Write-Host "WARN: status-contract.json 解析失敗,使用內建後備終態清單" }
}

function Get-WorkflowState([string]$dir) {
  # 回傳:terminal / truncated / none(沒用 workflow)
  $tasks = Get-ChildItem "$dir\.fable\runs\*\TASK.md" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
  if (-not $tasks) { return @{ state = 'none'; status = '' } }
  $raw = Get-Content $tasks[0].FullName -Raw
  $status = ''
  $m = [regex]::Matches($raw, '狀態[^\w]{0,6}([a-z_]+)')
  # 後備:紀錄員雖被要求固定寫「狀態=<token>」,但曾實證翻譯成英文標頭(2026-07-06 金絲雀)——雙保險
  if ($m.Count -eq 0) { $m = [regex]::Matches($raw, '(?i)Current State[^\w]{0,8}([a-z_]+)') }
  if ($m.Count -gt 0) { $status = $m[$m.Count - 1].Groups[1].Value }
  if ($terminal -contains $status) { return @{ state = 'terminal'; status = $status } }
  return @{ state = 'truncated'; status = $status }
}

function Get-LastResult([string]$logPath) {
  $result = $null
  if (-not (Test-Path $logPath)) { return $null }
  foreach ($line in (Get-Content $logPath)) {
    try { $ev = $line | ConvertFrom-Json } catch { continue }
    if ($ev.type -eq 'result' -and $ev.result) { $result = $ev.result }
  }
  return $result
}

function Get-RunCost([string]$logPath) {
  # 成本遙測:stream-json 的 result 事件自帶 total_cost_usd 與 usage —— 直接取用,不自行估價
  $cost = $null; $inTok = 0; $outTok = 0
  if (-not (Test-Path $logPath)) { return $null }
  foreach ($line in (Get-Content $logPath)) {
    try { $ev = $line | ConvertFrom-Json } catch { continue }
    if ($ev.type -eq 'result') {
      if ($null -ne $ev.total_cost_usd) { $cost = [double]$ev.total_cost_usd }
      if ($ev.usage) {
        if ($ev.usage.input_tokens) { $inTok = [long]$ev.usage.input_tokens }
        if ($ev.usage.output_tokens) { $outTok = [long]$ev.usage.output_tokens }
      }
    }
  }
  if ($null -eq $cost -and $inTok -eq 0 -and $outTok -eq 0) { return $null }
  return @{ cost = $cost; in = $inTok; out = $outTok }
}

if (-not (Test-Path $Target)) { Write-Error "目標不存在:$Target"; exit 1 }
$logDir = Join-Path $Target '.fable\run-logs'
New-Item -ItemType Directory -Force $logDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

Push-Location $Target
try {
  Write-Host "===== fable-run 第 0 輪 ====="
  $log = "$logDir\$stamp-r0.jsonl"
  claude -p $Task --model $Model --permission-mode acceptEdits --allowedTools $AllowedTools --output-format stream-json --verbose *> $log

  $resumes = 0
  while ($true) {
    $ws = Get-WorkflowState $Target
    if ($ws.state -ne 'truncated') {
      Write-Host "狀態:$($ws.state) $($ws.status) —— 無需續跑"
      break
    }
    if ($resumes -ge $MaxResumes) {
      Write-Host "⚠ 已達續跑上限($MaxResumes),TASK 狀態仍為「$($ws.status)」。交付檢查點與留痕見 .fable/;請人工接手。"
      break
    }
    $resumes++
    Write-Host "===== 偵測到截斷(狀態:$($ws.status)),第 $resumes 次續跑 ====="
    $resumeMsg = 'fable-emu workflow 疑似被 headless 收工截斷(TASK.md 停在非終態)。請:(1) 從上輪 Workflow 工具結果找出 runId;(2) 以 resumeFromRunId 續跑同一 workflow(已完成的 agent 呼叫會從快取秒回);(3) 跑完後把最終結果連同證據彙整輸出。不得以「已啟動,完成會通知」結束回合——等它完成。若 runId 已不可用,依 TASK.md 的已完成步驟從斷點以 Tier 1 方式手動完成剩餘工作並更新 TASK 狀態為終態。'
    $log = "$logDir\$stamp-r$resumes.jsonl"
    claude -p --continue $resumeMsg --model $Model --permission-mode acceptEdits --allowedTools $AllowedTools --output-format stream-json --verbose *> $log
  }

  Write-Host "`n===== 最終回覆 ====="
  $final = Get-LastResult $log
  if ($final) { Write-Host $final } else { Write-Host "(無法從 log 抽取最終回覆,見 $log)" }

  # ===== 成本遙測:逐輪加總,印出並 append 到 .fable/COST-LOG.md(信封宣稱的自我審計數據) =====
  $totalCost = 0.0; $totalIn = 0; $totalOut = 0; $rounds = 0; $hasCost = $false
  foreach ($lg in (Get-ChildItem "$logDir\$stamp-r*.jsonl" -ErrorAction SilentlyContinue)) {
    $c = Get-RunCost $lg.FullName
    if ($c) {
      $rounds++
      if ($null -ne $c.cost) { $totalCost += $c.cost; $hasCost = $true }
      $totalIn += $c.in; $totalOut += $c.out
    }
  }
  $ws2 = Get-WorkflowState $Target
  $costStr = if ($hasCost) { '${0:N2}' -f $totalCost } else { '(無 total_cost_usd 欄位)' }
  Write-Host "`n===== 成本遙測 ====="
  Write-Host "本次共 $rounds 輪;成本:$costStr;tokens in/out:$totalIn/$totalOut"
  $taskSnippet = if ($Task.Length -gt 60) { $Task.Substring(0, 60) + '…' } else { $Task }
  Add-Content -Path (Join-Path $Target '.fable\COST-LOG.md') -Encoding utf8 -Value (
    "- [{0}] {1} | 輪數={2} | 成本={3} | tokens={4}/{5} | 終態={6}" -f
    (Get-Date -Format 'yyyy-MM-dd HH:mm'), $taskSnippet, $rounds, $costStr, $totalIn, $totalOut, $ws2.status)
} finally {
  Pop-Location
}
