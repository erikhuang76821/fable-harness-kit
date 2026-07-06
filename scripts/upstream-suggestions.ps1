# 艦隊回流:把本專案 .fable/KIT-SUGGESTIONS.md 裡「已核准且 kit 通用」的建議,回流成 kit repo 的 GitHub issue
# 解決 template 部署天生不回流的問題——N 個部署專案 = N 個金絲雀感測器,教訓集中回 kit 上游
# 用法:powershell -File scripts\upstream-suggestions.ps1 [-Repo erikhuang76821/fable-harness-kit] [-Apply]
#   預設 dry-run(只列出將回流的條目);加 -Apply 才真的開 issue 並在原檔標記 [upstreamed]
# 判準:只回流 [accepted] 且未標 [upstreamed] 的條目;專案特定的建議請人工改標 [local] 排除

param(
  [string]$Repo = 'erikhuang76821/fable-harness-kit',
  [switch]$Apply
)

$sug = '.fable\KIT-SUGGESTIONS.md'
if (-not (Test-Path $sug)) { Write-Host "本專案無 $sug,無可回流"; exit 0 }

# gh CLI 可用性(缺席時降級為指引,不硬失敗)
$ghOk = $false
try { gh auth status *> $null; $ghOk = ($LASTEXITCODE -eq 0) } catch {}

$lines = Get-Content $sug -Encoding utf8
$targets = @()
foreach ($l in $lines) {
  if ($l -match '^\s*-\s*\[accepted\]' -and $l -notmatch '\[upstreamed\]' -and $l -notmatch '\[local\]') {
    $targets += $l
  }
}

if (-not $targets) { Write-Host "無待回流條目([accepted] 且未標 [upstreamed]/[local])"; exit 0 }

Write-Host "待回流 $($targets.Count) 條 → ${Repo}:"
$targets | ForEach-Object { Write-Host "  $_" }

if (-not $Apply) {
  Write-Host ""
  Write-Host "dry-run 結束。確認後加 -Apply 執行;專案特定條目請先在原檔加 [local] 標記排除。"
  exit 0
}
if (-not $ghOk) { Write-Error "gh CLI 未登入,無法開 issue(gh auth login 後重試)"; exit 1 }

$projName = Split-Path (Get-Location) -Leaf
foreach ($t in $targets) {
  $body = $t.Trim()
  $title = ($body -replace '^\s*-\s*\[accepted\]\s*', '') -replace '\(證據:.*$', ''
  if ($title.Length -gt 70) { $title = $title.Substring(0, 70) + '…' }
  gh issue create --repo $Repo --title "[fleet] $title" --body "來源專案:$projName(艦隊回流,scripts/upstream-suggestions.ps1)`n`n$body" | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "已回流:$title"
    $lines = $lines | ForEach-Object { if ($_ -eq $t) { $_ -replace '\[accepted\]', '[accepted][upstreamed]' } else { $_ } }
  } else {
    Write-Host "回流失敗(gh exit $LASTEXITCODE):$title —— 原檔不標記,可重試"
  }
}
Set-Content -Path $sug -Value $lines -Encoding utf8
Write-Host "完成;已回流條目在原檔標記 [upstreamed],不會重複回流。"
