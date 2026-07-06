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

$parts = $At -split '\s+'
$day = $parts[0].ToUpper().Substring(0, 3)
$time = $parts[1]
$canary = Join-Path $PSScriptRoot 'canary.ps1'
$logPath = Join-Path $env:TEMP 'fable-canary-weekly.log'
$cmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command `"& '$canary' *>> '$logPath'`""

schtasks /Create /F /TN $taskName /SC WEEKLY /D $day /ST $time /TR $cmd
if ($LASTEXITCODE -eq 0) {
  Write-Host "已註冊:每週 $day $time 跑金絲雀;log:$logPath"
  Write-Host "驗收方式:隔週檢查 log 末段的「金絲雀驗收清單」——終態非 done 或 pytest 非全綠 = 上游行為漂移警報。"
  Write-Host "解除:powershell -File scripts\schedule-canary.ps1 -Unregister"
} else {
  Write-Error "schtasks 註冊失敗(exit $LASTEXITCODE)"
}
