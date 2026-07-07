# doctor:fable-harness-kit 環境與安裝狀態一鍵自檢(預設 <5 秒,只查不改)
# 用法:powershell -File scripts\doctor.ps1 [-RunTests](加 -RunTests 會實跑 Pester + node 契約測試,約 1-2 分鐘)

param([switch]$RunTests)

$ok = 0; $warn = 0
function Check([bool]$pass, [string]$label, [string]$hint = '') {
  if ($pass) { Write-Host ("  [v] " + $label); $script:ok++ }
  else { Write-Host ("  [x] " + $label + $(if ($hint) { " —— $hint" } else { '' })); $script:warn++ }
}

Write-Host "===== fable-harness doctor ====="

Write-Host "`n-- 必要環境 --"
Check ($null -ne (Get-Command git -ErrorAction SilentlyContinue)) 'git' '未安裝 git,hooks 留痕與審查層都需要'
Check ($null -ne (Get-Command node -ErrorAction SilentlyContinue)) 'node' '未安裝 node,workflow 契約測試需要'
Check ($null -ne (Get-Module -ListAvailable Pester)) 'Pester' 'PS 內建通常已有;hooks 契約測試需要'
Check (Test-Path "$env:ProgramFiles\Git\bin\bash.exe") 'Git Bash' '跨模型裁判/橋接的傳輸層需要'

Write-Host "`n-- 跨模型審查 CLI(任一即可,都沒有會自動降級同家族人格團)--"
$hasCodex = $null -ne (Get-Command codex -ErrorAction SilentlyContinue)
$hasAgy = $null -ne (Get-Command agy -ErrorAction SilentlyContinue)
Check ($hasCodex -or $hasAgy) "codex:$hasCodex / agy:$hasAgy" '兩者皆缺 → 審查降級(功能仍完整,盲點覆蓋較弱)'

Write-Host "`n-- kit 安裝狀態(目前目錄)--"
Check (Test-Path '.claude\workflows\fable-emu.js') 'workflow 已鋪設' '先跑 init.ps1 -Target <本目錄>'
$settingsOk = $false
if (Test-Path '.claude\settings.json') {
  $s = Get-Content '.claude\settings.json' -Raw
  $settingsOk = @('session-brief', 'git-guard', 'rule-guard', 'verify-gate', 'stop-retro-gate', 'prompt-nudge') |
    Where-Object { $s -notmatch $_ } | Measure-Object | ForEach-Object { $_.Count -eq 0 }
}
Check $settingsOk '六支 hooks 已註冊' 'settings.json 缺 handler —— 若是既有專案 merge,見 init.ps1 結尾的 MERGE 指引'

$todoTotal = 0
foreach ($rel in @('CLAUDE.md', 'CONTEXT.md', 'docs\invariants.md', 'docs\DECISION-CORE.md')) {
  if (Test-Path $rel) { $todoTotal += ([regex]::Matches((Get-Content $rel -Raw), 'TODO')).Count }
}
Check ($todoTotal -eq 0) "模板 TODO 已填完(剩 $todoTotal 處)" '在 Claude Code 輸入 /fable-setup 可自動偵測填寫'

if ($RunTests) {
  Write-Host "`n-- 契約測試(-RunTests)--"
  $p = Invoke-Pester -Path tests -Quiet -PassThru -ErrorAction SilentlyContinue
  Check ($p -and $p.FailedCount -eq 0) "Pester:$($p.PassedCount) 過 / $($p.FailedCount) 敗"
  node --test tests/workflow-contract.test.mjs tests/persona-sync.test.mjs *> $null
  Check ($LASTEXITCODE -eq 0) 'workflow 契約測試(node --test)'
}

Write-Host "`n===== 結果:$ok 項通過,$warn 項待處理 ====="
if ($warn -eq 0) {
  Write-Host "全綠。下一步:丟一個小任務試跑(或在 Claude Code 輸入 /fable-setup 走完引導)。"
} else {
  Write-Host "最快修復路徑:在 Claude Code 輸入 /fable-setup,讓它逐項處理上面的 [x]。"
}
exit $(if ($warn -eq 0) { 0 } else { 1 })
