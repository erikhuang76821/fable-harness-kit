# Benchmark 盲評器:兩臂 diff 匿名化(X/Y 隨機),送非 Claude 家族雙裁判(codex + agy/Gemini)
# 協議:PROTOCOL.md——僅雙臂驗收皆過的任務進品質盲評;裁判原始回覆全文留檔;映射檔評分後才揭盲
# 用法:powershell -File benchmark\judge.ps1 -ResultsFile benchmark\results\results-<stamp>.jsonl

param([Parameter(Mandatory = $true)][string]$ResultsFile)

$benchDir = $PSScriptRoot
$resultsDir = Join-Path $benchDir 'results'
$rows = Get-Content $ResultsFile -Encoding utf8 | ForEach-Object { $_ | ConvertFrom-Json }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Get-ArmDiff([string]$wd) {
  Push-Location $wd
  try {
    git add -A *> $null
    $d = git diff --cached HEAD -- . ':(exclude).claude' ':(exclude)CLAUDE.md' ':(exclude)CONTEXT.md' ':(exclude)docs' ':(exclude)tests' ':(exclude)scripts' ':(exclude)fable-run.ps1' ':(exclude).fable' ':(exclude).gitignore' ':(exclude)bench-fable.jsonl' 2>&1 | Out-String
    return $d
  } finally { Pop-Location }
}

$tasks = $rows | Group-Object task
foreach ($g in $tasks) {
  $fable = $g.Group | Where-Object { $_.arm -eq 'fable' } | Select-Object -First 1
  $kit = $g.Group | Where-Object { $_.arm -eq 'kit' } | Select-Object -First 1
  if (-not $fable -or -not $kit) { Write-Host "[$($g.Name)] 缺臂,跳過盲評"; continue }
  if (-not $fable.pass -or -not $kit.pass) { Write-Host "[$($g.Name)] 有臂未過驗收(fable=$($fable.pass) kit=$($kit.pass)),依協議不進品質盲評"; continue }

  # 匿名化:隨機決定 X/Y 映射,評分完成前不揭盲
  $swap = ((Get-Random -Maximum 2) -eq 1)
  $x = if ($swap) { $kit } else { $fable }
  $y = if ($swap) { $fable } else { $kit }
  @{ task = $g.Name; X = $x.arm; Y = $y.arm } | ConvertTo-Json |
    Set-Content (Join-Path $resultsDir "judge-mapping-$($g.Name)-$stamp.json") -Encoding utf8

  $taskText = (Get-Content (Join-Path $benchDir "fixtures\$($g.Name)\task.txt") -Raw -Encoding utf8).Trim()
  $promptFile = Join-Path $resultsDir "judge-prompt-$($g.Name)-$stamp.txt"
  @"
回答前,先用一句話複述你被要求評分的任務;若看不到具體 diff,回覆 ECHO-FAIL。

盲評:兩個匿名實作(X 與 Y)解了同一任務,兩者都通過了自動化驗收。請比較品質。
任務:$taskText

===== 實作 X 的 diff =====
$(Get-ArmDiff $x.workdir)

===== 實作 Y 的 diff =====
$(Get-ArmDiff $y.workdir)

請分別給 X 與 Y 評分(各 0-10,獨立評,不是排名):
- correctness:測試覆蓋之外的正確性(邊界、隱藏缺陷)
- scope:範圍紀律(是否只做被要求的事,無順手改動)
- quality:程式品質(可讀、貼合既有慣例、無過度工程)
輸出固定格式:
X: correctness=<n> scope=<n> quality=<n>
Y: correctness=<n> scope=<n> quality=<n>
verdict: <X|Y|tie> — <一句話理由>
"@ | Set-Content $promptFile -Encoding utf8

  Write-Host "[$($g.Name)] 送雙裁判盲評…"
  $codexOut = codex exec --sandbox read-only "$(Get-Content $promptFile -Raw -Encoding utf8)" 2>&1 | Out-String
  $codexOut | Set-Content (Join-Path $resultsDir "judge-$($g.Name)-codex-$stamp.txt") -Encoding utf8
  $agyOut = agy --model "Gemini 3.1 Pro (High)" -p "$(Get-Content $promptFile -Raw -Encoding utf8)" 2>&1 | Out-String
  $agyOut | Set-Content (Join-Path $resultsDir "judge-$($g.Name)-agy-$stamp.txt") -Encoding utf8
  Write-Host "[$($g.Name)] 完成;原始回覆與映射已留檔於 benchmark\results\"
}
Write-Host "盲評結束。揭盲與彙整:對照 judge-mapping-*.json 讀 judge-*-{codex,agy}.txt。"
