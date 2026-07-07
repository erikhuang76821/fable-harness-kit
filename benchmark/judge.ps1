# Benchmark 盲評器:兩臂 diff 匿名化(X/Y 隨機),送非 Claude 家族雙裁判(codex + agy/Gemini)
# 協議:PROTOCOL.md——僅雙臂驗收皆過的任務進品質盲評;裁判原始回覆全文留檔;映射檔評分後才揭盲
# 用法:powershell -File benchmark\judge.ps1 -ResultsFile benchmark\results\results-<stamp>.jsonl

param([Parameter(Mandatory = $true)][string]$ResultsFile)

$benchDir = $PSScriptRoot
$resultsDir = Join-Path $benchDir 'results'
$rows = Get-Content $ResultsFile -Encoding utf8 | ForEach-Object { $_ | ConvertFrom-Json }

# 解析 Git Bash 完整路徑(排程/純 PS 環境的 PATH 通常沒有 bash;經 bash 傳遞是為了
# 防 prompt 內嵌雙引號打爆 PS 原生參數傳遞——兩個坑都是實證)
$bash = $null
foreach ($cand in @("$env:ProgramFiles\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe")) {
  if (Test-Path $cand) { $bash = $cand; break }
}
if (-not $bash) {
  $git = (Get-Command git -ErrorAction SilentlyContinue).Source
  if ($git) { $cand = Join-Path (Split-Path (Split-Path $git -Parent) -Parent) 'bin\bash.exe'; if (Test-Path $cand) { $bash = $cand } }
}
if (-not $bash) { Write-Error '找不到 Git Bash(bash.exe)——裁判傳輸層依賴它,中止'; exit 1 }

function ConvertTo-Posix([string]$p) { '/' + $p.Substring(0, 1).ToLower() + $p.Substring(2).Replace('\', '/') }

# PS→native 的參數只要含雙引號就會被切碎(本日第四次實證)——命令一律寫成 .sh 檔再執行,
# bash 只收純路徑參數;.sh 必須 LF 結尾、無 BOM,否則 bash 吃到 \r 會炸
function Invoke-ViaBash([string]$cmd, [string]$tag) {
  $shPath = Join-Path $resultsDir "call-$tag.sh"
  [System.IO.File]::WriteAllText($shPath, $cmd + "`n", (New-Object System.Text.UTF8Encoding($false)))
  return (& $bash -l (ConvertTo-Posix $shPath) 2>&1 | Out-String)
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Get-ArmDiff([string]$wd) {
  Push-Location $wd
  try {
    git add -A *> $null
    # __pycache__/*.pyc 是驗收腳本跑 pytest 的產物,非模型行為;kit 臂帶 .gitignore 自動豁免
    # 而裸臂沒有 → 不排除會系統性偏向 kit 臂(2026-07-07 傳輸驗證時實證)
    $d = git diff --cached HEAD -- . ':(exclude).claude' ':(exclude)CLAUDE.md' ':(exclude)CONTEXT.md' ':(exclude)docs' ':(exclude)tests' ':(exclude)scripts' ':(exclude)benchmark' ':(exclude)fable-run.ps1' ':(exclude).fable' ':(exclude).gitignore' ':(exclude)bench-fable.jsonl' ':(exclude)__pycache__' ':(exclude)*.pyc' ':(exclude)*/__pycache__/*' 2>&1 | Out-String
    return $d
  } finally { Pop-Location }
}

$tasks = $rows | Group-Object task
foreach ($g in $tasks) {
  $fable = $g.Group | Where-Object { $_.arm -eq 'fable' } | Select-Object -First 1
  $kit = $g.Group | Where-Object { $_.arm -eq 'kit' } | Select-Object -First 1
  if (-not $fable -or -not $kit) { Write-Host "[$($g.Name)] 缺臂,跳過盲評"; continue }
  if (-not $fable.pass -or -not $kit.pass) { Write-Host "[$($g.Name)] 有臂未過驗收(fable=$($fable.pass) kit=$($kit.pass)),依協議不進品質盲評"; continue }

  # 匿名化:隨機決定 X/Y 映射。映射只留在記憶體,**兩位裁判都評完才落盤**——
  # 裁判(codex read-only)能讀 repo 檔案,提前落盤 = 洩盲(Codex 審查發現)
  $swap = ((Get-Random -Maximum 2) -eq 1)
  $x = if ($swap) { $kit } else { $fable }
  $y = if ($swap) { $fable } else { $kit }
  $mapping = @{ task = $g.Name; X = $x.arm; Y = $y.arm }

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
  # 經 bash 傳遞:prompt 內含 diff 的 " 字元會打爆 PowerShell 原生引號傳遞(實證:docstring 的三引號
  # 讓 codex 把 diff 碎片當參數);bash 的 "$(cat file)" 對內嵌雙引號安全,且為既有成功模式
  $posix = ConvertTo-Posix $promptFile
  # < /dev/null 必要:PS 環境下 stdin pipe 不關閉,codex exec 偵測到 piped stdin 會永遠等 EOF
  # (實證:掛死 6 小時、CPU 0 分)。cd 到 kit repo 必要:bash -l 起始於 HOME,codex 要求受信任目錄
  $kitPosix = ConvertTo-Posix (Split-Path $benchDir -Parent)
  $codexOut = Invoke-ViaBash ('cd ' + $kitPosix + ' && codex exec --sandbox read-only "$(cat ' + $posix + ')" < /dev/null') "$($g.Name)-codex"
  $codexOut | Set-Content (Join-Path $resultsDir "judge-$($g.Name)-codex-$stamp.txt") -Encoding utf8
  $agyOut = Invoke-ViaBash ('cd ' + $kitPosix + ' && agy --model "Gemini 3.1 Pro (High)" -p "$(cat ' + $posix + ')" < /dev/null') "$($g.Name)-agy"
  $agyOut | Set-Content (Join-Path $resultsDir "judge-$($g.Name)-agy-$stamp.txt") -Encoding utf8
  # 評分完成,此刻才揭盲落盤
  $mapping | ConvertTo-Json | Set-Content (Join-Path $resultsDir "judge-mapping-$($g.Name)-$stamp.json") -Encoding utf8
  Write-Host "[$($g.Name)] 完成;原始回覆與映射(評後落盤)已留檔於 benchmark\results\"
}
Write-Host "盲評結束。揭盲與彙整:對照 judge-mapping-*.json 讀 judge-*-{codex,agy}.txt。"
