# 金絲雀:fable-emu.js 修改後的一鍵端到端實跑(unit test 保契約,金絲雀保現實——兩層互證)
# 固定 fixture(修一個單檔 bug 使 pytest 全綠),不靠臨場手寫;log artifact 留在工作目錄供 review 佐證。
# 用法:powershell -File scripts\canary.ps1 [-Workdir <路徑>] [-SetupOnly]
#   -SetupOnly:只鋪 fixture 不呼叫 claude(零成本驗證腳本本身)
# 成本預估:~$1 / 10-30 分鐘(Tier 2 全管線)。無 CI 環境下這是弱保護:merge 前人工執行並貼結果。

param(
  [string]$Workdir = (Join-Path $env:TEMP ("fable-canary-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))),
  [switch]$SetupOnly
)

$kitRoot = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Force $Workdir | Out-Null
Write-Host "金絲雀工作目錄:$Workdir"

# 1) 鋪 kit(init.ps1 只增不覆蓋)
& (Join-Path $kitRoot 'init.ps1') -Target $Workdir | Out-Null

# 2) 固定 fixture:一個有 bug 的模組 + 會抓到它的測試
Set-Content -Path (Join-Path $Workdir 'calc.py') -Encoding utf8 -Value @'
def add(a, b):
    """回傳 a 與 b 的和。"""
    return a - b  # BUG: 應為加法
'@
Set-Content -Path (Join-Path $Workdir 'test_calc.py') -Encoding utf8 -Value @'
from calc import add

def test_add_basic():
    assert add(1, 2) == 3

def test_add_negative():
    assert add(-1, -2) == -3

def test_add_zero():
    assert add(0, 5) == 5
'@

# 3) git init(fable-emu 的審查層依賴 git diff)
Push-Location $Workdir
try {
  git init -q 2>$null
  git add -A 2>$null
  git commit -q -m "canary fixture" 2>$null
} finally { Pop-Location }

if ($SetupOnly) {
  Write-Host "SetupOnly:fixture 已就緒(未呼叫 claude)。手動跑:powershell -File `"$kitRoot\fable-run.ps1`" -Task <下方任務> -Target `"$Workdir`""
  exit 0
}

# 4) 經 fable-run 監督跑 fable-emu(headless 鐵律:不得裸呼 claude -p)
$task = '用 fable-emu workflow 處理:修復 calc.py 的 add 函式(目前行為錯誤),使 python -m pytest test_calc.py -q 全綠。'
Write-Host "啟動金絲雀 run(經 fable-run 監督)..."
& (Join-Path $kitRoot 'fable-run.ps1') -Task $task -Target $Workdir

# 5) 收尾:印驗收要點,artifact 位置供 review 佐證
Write-Host ""
Write-Host "===== 金絲雀驗收清單 ====="
$tasks = Get-ChildItem "$Workdir\.fable\runs\*\TASK.md" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($tasks) {
  $raw = Get-Content $tasks[0].FullName -Raw
  $m = [regex]::Matches($raw, '狀態[^\w]{0,6}([a-z_]+)')
  $status = if ($m.Count -gt 0) { $m[$m.Count - 1].Groups[1].Value } else { '(未知)' }
  Write-Host "1. TASK 終態:$status(期望 done)"
} else { Write-Host "1. TASK.md 不存在 —— workflow 可能未啟動,檢查 run-logs" }
Push-Location $Workdir
try {
  $pytest = python -m pytest test_calc.py -q 2>&1 | Select-Object -Last 1
  Write-Host "2. pytest 實測:$pytest(期望 3 passed)"
} finally { Pop-Location }
Write-Host "3. 審查模式:grep TASK.md 的「模式:」——cross-model 為佳,same-family-panel 需附降級原因"
Write-Host "4. artifact:$Workdir\.fable\(run-logs / TASK.md / DECISIONS.md)——merge 前把本清單結果貼進 PR/回報"
