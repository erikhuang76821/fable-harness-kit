# fable-harness-kit 初始化腳本
# 用法:powershell -NoProfile -ExecutionPolicy Bypass -File .\init.ps1 -Target C:\path\to\repo
# 行為:把套件內容(除 README.md 與本腳本)照結構複製到目標 repo;已存在的檔案一律跳過,絕不覆蓋。

param(
  [Parameter(Mandatory = $true)]
  [string]$Target
)

$src = $PSScriptRoot
if (-not (Test-Path $Target -PathType Container)) {
  Write-Error "目標資料夾不存在:$Target"
  exit 1
}

$exclude = @('README.md', 'README.zh-TW.md', 'init.ps1', 'LICENSE')
# benchmark/ 是 kit 的開發材料(對照實驗協議與 fixtures),不是部署物——
# 且鋪進受測專案會污染 benchmark 公平性(kit 臂看得到題庫與驗收邏輯)
$excludePrefix = @('benchmark\')
$copied = 0
$skipped = 0

# Harness 共存偵測:目標已有自己的 hooks/settings 時,只增不覆蓋的複製會「靜默不註冊」本 kit 的 hooks
$hadSettings = Test-Path (Join-Path $Target '.claude\settings.json')
$hadHooks = Test-Path (Join-Path $Target '.claude\hooks')
$hadOtherHarness = @(Get-ChildItem (Join-Path $Target '.claude\skills') -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'superpowers|harnessmith' }).Count -gt 0
if ($hadSettings -or $hadHooks -or $hadOtherHarness) {
  Write-Host "NOTE: 偵測到既有 harness 痕跡(settings.json:$hadSettings / hooks:$hadHooks / 其他 harness skill:$hadOtherHarness)。"
  Write-Host "      本腳本照舊只複製不存在的檔案、絕不覆蓋;既有 settings.json 會被跳過 → 本 kit 的 hooks 不會自動生效,見結尾的 merge 指引。"
}

Get-ChildItem -Path $src -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($src.Length + 1)
  if ($exclude -contains $rel) { return }
  foreach ($p in $excludePrefix) { if ($rel.StartsWith($p)) { return } }
  $dest = Join-Path $Target $rel
  if (Test-Path $dest) {
    Write-Host "SKIP(已存在,未覆蓋): $rel"
    $script:skipped++
    return
  }
  $destDir = Split-Path $dest -Parent
  New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  Copy-Item $_.FullName $dest
  Write-Host "COPY: $rel"
  $script:copied++
}

Write-Host ""
Write-Host "完成:複製 $copied 個檔案,跳過 $skipped 個既有檔案。"

# 自檢:關鍵模板的 TODO 未填完前,驗證與完整性批評缺少專案事實基準,harness 未完整啟用
$todoTotal = 0
foreach ($rel in @('CLAUDE.md', 'CONTEXT.md', 'docs\invariants.md', 'docs\DECISION-CORE.md')) {
  $p = Join-Path $Target $rel
  if (Test-Path $p) {
    $n = ([regex]::Matches((Get-Content $p -Raw), 'TODO\(')).Count
    if ($n -gt 0) { Write-Host "WARN: $rel 尚有 $n 處 TODO 未填"; $todoTotal += $n }
  }
}
if ($todoTotal -gt 0) {
  Write-Host "WARN: 共 $todoTotal 處 TODO —— 填完前 harness 只有流程強制力,缺少專案事實基準(build/test 指令、不變量)。"
}
if ($hadSettings) {
  Write-Host ""
  Write-Host "MERGE 指引:目標已有 .claude\settings.json(未覆蓋)。要啟用本 kit 的 hooks,請手動把以下 handler 併入既有陣列(勿整段替換):"
  Write-Host "  SessionStart(startup|clear|compact)→ hooks/session-brief.ps1"
  Write-Host "  UserPromptSubmit → hooks/prompt-nudge.ps1"
  Write-Host "  PreToolUse(Bash|PowerShell)→ hooks/git-guard.ps1"
  Write-Host "  PostToolUse(Edit|MultiEdit|Write)→ hooks/rule-guard.ps1"
  Write-Host "  Stop → hooks/verify-gate.ps1 + hooks/stop-retro-gate.ps1(順序:verify 在前)"
  Write-Host "  完整格式參考本套件的 .claude\settings.json"
}
if ($hadOtherHarness) {
  Write-Host ""
  Write-Host "共存建議:偵測到其他開發 harness(如 Superpowers)。分工原則:SDLC 主流程讓給該 harness,"
  Write-Host "  本 kit 只守底線(危險指令攔截、證據閘門、收尾檢討、.fable/ 留痕);fable-emu 僅在使用者點名時跑,避免雙 harness 搶編排。"
}
Write-Host ""
Write-Host "接下來(推薦路徑):"
Write-Host "  1. 在目標專案開 Claude Code,輸入 /fable-setup —— 自動填模板、自檢、可選 lint、試跑"
Write-Host "  2. 完成後跑 powershell -File scripts\doctor.ps1 確認全綠"
Write-Host "  (手動路徑見 README 的進階摺疊區)"

