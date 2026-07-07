# Stop hook:全 tier 收尾檢討閘門
# 觸發條件:本 session 有 Edit/Write 修改,且既沒寫過教訓也沒聲明「檢討:無」→ block 一次,要求收尾檢討
# 防護:stop_hook_active 時放行(防無限迴圈);非 kit 專案放行;無修改放行

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}  # 中文輸出必經:Claude Code 以 UTF-8 讀 hook 輸出,PS 5.1 預設主控台碼頁(CP950)會產生亂碼(2026-07-07 dogfood 實證)
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }

# 防迴圈:已經因本 hook 續跑過一次,不再攔
if ($payload.stop_hook_active) { exit 0 }

# 僅在 kit 專案生效
if (-not (Test-Path ".claude/workflows/fable-emu.js")) { exit 0 }

$t = $payload.transcript_path
if (-not $t -or -not (Test-Path $t)) { exit 0 }

# 本 session 是否改過檔案?(Edit/MultiEdit/Write/NotebookEdit 工具呼叫)
$edited = Select-String -Path $t -Pattern '"name"\s*:\s*"(Edit|MultiEdit|Write|NotebookEdit)"' -Quiet
if (-not $edited) { exit 0 }

# 是否已完成檢討?
# 注意:不能只比對「LESSONS.md」字樣 —— session-brief 注入、Read 呼叫都會讓它出現在 transcript。
# 判準:同一行同時出現「寫入型工具名」與「教訓檔名」(tool_use 為單行 JSON,寫入才算檢討)
$retroDone = Select-String -Path $t -Pattern '"name"\s*:\s*"(Edit|MultiEdit|Write)"[^\r\n]*(LESSONS|KIT-SUGGESTIONS)' -Quiet
$declaredNone = Select-String -Path $t -Pattern '檢討[::]\s*無' -Quiet
if ($retroDone -or $declaredNone) { exit 0 }

# 攔下,要求收尾檢討(僅一次;續跑後 stop_hook_active=true 放行)
$out = @{
  decision = 'block'
  reason   = '收尾檢討(hook 強制,僅此一次):本 session 修改過檔案。請花 30 秒判斷:有沒有值得記錄的教訓(被駁回的作法、踩過的坑、對 kit 的改進建議)?有 → 寫入 .fable/LESSONS.md 或 .fable/KIT-SUGGESTIONS.md(格式:- [pending] 建議(證據:...;日期));沒有 → 在回覆中聲明「檢討:無」即可結束。'
}
$out | ConvertTo-Json -Compress
exit 0
