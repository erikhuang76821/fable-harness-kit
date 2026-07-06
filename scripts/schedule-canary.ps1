# 排程金絲雀:把 canary.ps1 註冊為 Windows 排程工作(每週一次)
# 目的:三模型分析公認的最後盲區——上游模型暗改(API 微調)在本地零 code 變更下改變行為,
#       所有靜態測試照綠。定時實跑是唯一感測器;成本 ~$1/週。
# 用法:powershell -File scripts\schedule-canary.ps1 [-At "Mon 09:30"] [-Unregister]
# 註:排程以「目前使用者」身分執行,需該使用者的 claude CLI 已登入;log 落在 %TEMP%\fable-canary-weekly.log

param(
  [string]$At = 'Mon 09:30',
  [switch]$Unregister
)

$taskName = 'fable-canary-weekly'

if ($Unregister) {
  schtasks /Delete /TN $taskName /F
  exit $LASTEXITCODE
}

if ($At -notmatch '^([A-Za-z]{3,})\s+(\d{1,2}:\d{2})$') {
  Write-Error "無效的 -At 格式:「$At」。格式:<星期> <HH:mm>,例:Mon 09:30"
  exit 1
}
$day = $Matches[1].ToUpper().Substring(0, 3)
$time = $Matches[2]
$canary = Join-Path $PSScriptRoot 'canary.ps1'
if (-not (Test-Path $canary)) { Write-Error "canary.ps1 不存在:$canary(不註冊指向空檔的排程)"; exit 1 }
$logPath = Join-Path $env:TEMP 'fable-canary-weekly.log'
# schtasks /TR 的引號嵌套很脆:改走 cmd /c + 反斜線跳脫雙引號(PS→native 傳遞後成為字面引號)
$cmd = 'cmd /c powershell -NoProfile -ExecutionPolicy Bypass -File \"' + $canary + '\" >> \"' + $logPath + '\" 2>&1'

schtasks /Create /F /TN $taskName /SC WEEKLY /D $day /ST $time /TR $cmd
if ($LASTEXITCODE -eq 0) {
  Write-Host "已註冊:每週 $day $time 跑金絲雀;log:$logPath"
  Write-Host "驗收方式:隔週檢查 log 末段的「金絲雀驗收清單」——終態非 done 或 pytest 非全綠 = 上游行為漂移警報。"
  Write-Host "解除:powershell -File scripts\schedule-canary.ps1 -Unregister"
} else {
  Write-Error "schtasks 註冊失敗(exit $LASTEXITCODE)"
}
