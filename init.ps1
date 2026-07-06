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

$exclude = @('README.md', 'init.ps1', 'LICENSE')
$copied = 0
$skipped = 0

Get-ChildItem -Path $src -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($src.Length + 1)
  if ($exclude -contains $rel) { return }
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
foreach ($rel in @('CLAUDE.md', 'CONTEXT.md', 'docs\invariants.md', 'DECISION-CORE.md')) {
  $p = Join-Path $Target $rel
  if (Test-Path $p) {
    $n = ([regex]::Matches((Get-Content $p -Raw), 'TODO')).Count
    if ($n -gt 0) { Write-Host "WARN: $rel 尚有 $n 處 TODO 未填"; $todoTotal += $n }
  }
}
if ($todoTotal -gt 0) {
  Write-Host "WARN: 共 $todoTotal 處 TODO —— 填完前 harness 只有流程強制力,缺少專案事實基準(build/test 指令、不變量)。"
}
Write-Host "接下來(見套件 README.md 的檢查清單):"
Write-Host "  1. 填 CLAUDE.md 的 TODO(build/test/lint 指令、Tier 1 高風險區、規格來源)"
Write-Host "  2. 填 CONTEXT.md、docs/invariants.md、DECISION-CORE.md 的規格來源"
Write-Host "  3. 試跑一個 Tier 0 小任務驗證 hooks 生效"
